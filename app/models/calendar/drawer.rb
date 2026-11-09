module Calendar
  # The tasks drawer under the calendar: open tasks to put on a day, searched and filtered on their
  # own (the tasks_* params, apart from the calendar's). By default those with no due date yet, the
  # ones waiting to be planned; or overdue, due in the next two weeks, or any. The search is the
  # core's fuzzy Search: a task, its work, its client or someone on it.
  class Drawer
    DUES = { "none" => "No date", "overdue" => "Overdue", "soon" => "Next two weeks", "any" => "Any date" }.freeze
    LIMIT = 100

    attr_reader :due, :owner, :client, :work, :query

    def initialize(due: nil, owner: nil, client: nil, work: nil, query: nil)
      @due = due.presence_in(DUES.keys) || "none"
      @owner, @client, @work = owner, client, work
      @query = query.to_s.strip.presence
    end

    def tasks = @tasks ||= scope.limit(LIMIT).to_a
    def total = @total ||= scope.count
    def more? = total > tasks.size

    private
      def scope
        scope = Task.open.includes(:work, :client, :owner, { assignments: :user })
        scope = case due
        when "overdue" then scope.where(due_on: ...Date.current).order(:due_on)
        when "soon" then scope.where(due_on: Date.current..(Date.current + 14)).order(:due_on)
        when "any" then scope.order(Arel.sql("tasks.due_on IS NULL DESC"), :due_on)
        else scope.where(due_on: nil)
        end
        scope = owner == :nobody ? scope.where(owner_id: nil) : scope.assigned_to(owner) if owner
        scope = scope.where(client: client) if client
        scope = scope.where(work: work) if work
        scope = matching(scope) if query
        scope.order(created_at: :desc)
      end

      def matching(scope)
        search = Search.new(query)
        found = search.results.group_by { it.class.name }
        ids = ->(type) { Array(found[type]).map(&:id) }
        any = scope.where(id: ids.("Task")).or(scope.where(work_id: ids.("Work"))).or(scope.where(client_id: ids.("Client")))
        people = search.people.to_a
        people.any? ? any.or(scope.where(id: Task.assigned_to(people).select(:id))) : any
      end
  end
end
