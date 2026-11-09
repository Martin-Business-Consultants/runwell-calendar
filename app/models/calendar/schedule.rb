module Calendar
  # Everything dated in a range of days, as the calendar shows it: tasks by their due date (open,
  # overdue or done), who's out, every date field the viewer may see (a work's launch, a client's
  # renewal: CustomField.dates_between), and work closed (completed or cancelled). Narrowed by
  # person, client, work and what to show, and by a search (the core's fuzzy Search: a client,
  # work, task or person, with typos and partial words), all of it from the page's query params,
  # so the page and the list_calendar tool read the same.
  #
  # A clash is what makes it more than a picture: a task due on a day someone on it is out, or a
  # date on a piece of work (a launch) while someone working on it is out. Clashes are worked out
  # from everyone's time off, whatever the filters show.
  class Schedule
    SHOWS = { "all" => "Everything", "open" => "Open tasks", "overdue" => "Overdue", "done" => "Done tasks",
      "time_off" => "Time off", "dates" => "Dates", "closed" => "Closed work" }.freeze
    KIND_ORDER = %w[time_off date task closed].freeze

    # One thing on a day. kind: task, time_off, date or closed. people: who it's about (a task's
    # owners, lead first; the person out). clash: who's on it but out that day.
    Item = Data.define(:kind, :date, :title, :record, :people, :detail, :status, :clash) do
      def task? = kind == "task"
      def done? = task? && status == "done"
      def overdue? = task? && !done? && date < Date.current
      def clash? = clash.any?
    end

    attr_reader :range, :person, :client, :work, :show, :query, :viewer

    def initialize(range, person: nil, client: nil, work: nil, show: "all", query: nil, viewer: Current.user)
      @range, @person, @client, @work, @viewer = range, person, client, work, viewer
      @show = show.presence_in(SHOWS.keys) || "all"
      @query = query.to_s.strip.presence
    end

    def filtered? = person || client || work || show != "all" || query

    def items
      @items ||= (task_items + time_off_items + date_items + closed_items)
        .sort_by { [ it.date, KIND_ORDER.index(it.kind), it.done? ? 1 : 0, it.title.downcase ] }
    end

    def by_day = @by_day ||= items.group_by(&:date)
    def on(date) = by_day.fetch(date, [])

    # Open tasks due before today, under the same filters (wherever the range is): what Today
    # leads with.
    def overdue
      @overdue ||= narrow_tasks(Task.open.where(due_on: ...Date.current)).includes(*TASK_INCLUDES).order(:due_on).to_a
    end

    # Who's out on a day, whatever the filters, for the day's Out list and clashes.
    def out_on(date) = everyone_out.select { it.covers?(date) }

    # Open tasks due on a day per person (the lead and everyone on it): how loaded each is.
    def load_on(date)
      on(date).select { it.task? && !it.done? }.flat_map(&:people).tally.sort_by { |user, count| [ -count, user.display_name ] }
    end

    private
      TASK_INCLUDES = [ :work, :client, :owner, { assignments: :user } ].freeze

      def shows?(*kinds) = show == "all" || kinds.include?(show)

      def task_items
        return [] unless shows?("open", "overdue", "done")

        scope = Task.where(due_on: range)
        scope = case show
        when "open" then scope.open
        when "overdue" then scope.open.where(due_on: ...Date.current)
        when "done" then scope.where(status: "done")
        else scope
        end
        narrow_tasks(scope).includes(*TASK_INCLUDES).map do |task|
          owners = task.owners
          Item.new(kind: "task", date: task.due_on, title: task.title, record: task, people: owners,
            detail: task.work&.title || task.client&.name, status: task.status,
            clash: task.status == "done" ? [] : owners.select { out?(it, task.due_on) })
        end
      end

      def narrow_tasks(scope)
        scope = scope.assigned_to(person) if person
        scope = scope.where(client: client) if client
        scope = scope.where(work: work) if work
        return scope unless query

        any = scope.where(id: matches[:tasks]).or(scope.where(work_id: matches[:works])).or(scope.where(client_id: matches[:clients]))
        matches[:people].any? ? any.or(scope.where(id: Task.assigned_to(matches[:people]).select(:id))) : any
      end

      def time_off_items
        return [] unless shows?("time_off")

        offs = everyone_out
        offs = offs.select { it.user_id == person.id } if person
        offs = offs.select { |off| matches[:people].any? { it.id == off.user_id } } if query
        offs.flat_map do |off|
          off.days.select { range.cover?(it) }.map do |date|
            Item.new(kind: "time_off", date: date, title: off.user.display_name, record: off, people: [ off.user ],
              detail: off.label, status: nil, clash: [])
          end
        end
      end

      def date_items
        return [] unless shows?("dates")

        dated = CustomField.dates_between(range, viewer: viewer)
        tasks = dated.map(&:first).grep(Task)
        ActiveRecord::Associations::Preloader.new(records: tasks, associations: [ :owner, { assignments: :user } ]).call if tasks.any?
        @work_people = people_on_works(dated.map(&:first).grep(Work).map(&:id))

        dated.filter_map do |record, field, date|
          next unless keeps_record?(record)

          on_it = people_on(record)
          Item.new(kind: "date", date: date, title: record_title(record), record: record, people: on_it,
            detail: field.label, status: nil, clash: record.is_a?(Client) ? [] : on_it.select { out?(it, date) })
        end
      end

      def closed_items
        return [] unless shows?("closed")

        scope = Work.closed.where(closed_at: range.first.beginning_of_day..range.last.end_of_day).includes(:client)
        scope.select { keeps_record?(it) }.map do |closed|
          Item.new(kind: "closed", date: closed.closed_at.to_date, title: closed.title, record: closed, people: [],
            detail: closed.state_label, status: closed.close_outcome, clash: [])
        end
      end

      # A client's, work's or task's date (or a closed work) kept by the filters: its client, its
      # work, a person on it, or the search matching any of those.
      def keeps_record?(record)
        task, work_id, client_id = case record
        when Task then [ record, record.work_id, record.client_id ]
        when Work then [ nil, record.id, record.client_id ]
        else [ nil, nil, record.id ]
        end
        return false if client && client_id != client.id
        return false if work && work_id != work.id
        return false if person && !person_on?(person, task, work_id, client_id)
        return true unless query

        (task && matches[:tasks].include?(task.id)) || matches[:works].include?(work_id) || matches[:clients].include?(client_id) ||
          matches[:people].any? { person_on?(it, task, work_id, client_id) }
      end

      def person_on?(user, task, work_id, client_id)
        return task.assigned_to?(user) if task

        work_id ? work_ids_for(user).include?(work_id) : client_ids_for(user).include?(client_id)
      end

      def work_ids_for(user) = (@work_ids_for ||= {})[user.id] ||= Task.open.assigned_to(user).distinct.pluck(:work_id).compact.to_set
      def client_ids_for(user) = (@client_ids_for ||= {})[user.id] ||= Task.open.assigned_to(user).distinct.pluck(:client_id).compact.to_set

      # Who's working on a record: everyone on a task; on a piece of work, everyone on its open tasks.
      def people_on(record)
        case record
        when Task then record.owners
        when Work then @work_people.fetch(record.id, [])
        else []
        end
      end

      # Everyone on the open tasks of these pieces of work, by work.
      def people_on_works(ids)
        return {} if ids.empty?

        Task.open.where(work_id: ids).includes(:owner, assignments: :user).group_by(&:work_id)
          .transform_values { |tasks| tasks.flat_map(&:owners).uniq }
      end

      def record_title(record) = record.try(:title) || record.try(:name)

      def everyone_out = @everyone_out ||= TimeOff.overlapping(range).includes(:user).ordered.to_a

      def out?(user, date) = everyone_out.any? { it.user_id == user.id && it.covers?(date) }

      # What the search found: tasks, works and clients (fuzzy, ranked, as ids) and people by name.
      def matches
        @matches ||= begin
          search = Search.new(query)
          found = search.results.group_by { it.class.name }
          { tasks: ids(found["Task"]), works: ids(found["Work"]), clients: ids(found["Client"]), people: search.people.to_a }
        end
      end

      def ids(records) = Array(records).map(&:id).to_set
  end
end
