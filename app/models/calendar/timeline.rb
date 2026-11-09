module Calendar
  # The timeline: each open piece of work over the weeks shown, as a bar from its start to its last
  # date field (a launch, a deadline: CustomField.dates_between), with a marker for each date; one
  # with no date runs on past the edge. Narrowed by client, work, and person (work they're on).
  # Weeks and places are 1-based columns, kept to the weeks shown.
  class Timeline
    Row = Data.define(:work, :start, :finish, :dates)

    attr_reader :range

    def initialize(range, client: nil, work: nil, person: nil, viewer: Current.user)
      @range, @client, @work, @person, @viewer = range, client, work, person, viewer
    end

    def weeks = @weeks ||= range.each_slice(7).map(&:first)

    def rows
      @rows ||= begin
        dated = CustomField.dates_between((range.first - 365)..(range.last + 365), viewer: @viewer).select { |record, _, _| record.is_a?(Work) }
          .group_by { |record, _, _| record.id }
        works.filter_map do |work|
          dates = Array(dated[work.id]).map { |_, field, date| [ field.label, date ] }.sort_by(&:last)
          start = work.created_at.to_date
          finish = dates.last&.last
          next if start > range.last || (finish && finish < range.first)

          Row.new(work: work, start: start, finish: finish, dates: dates.select { |_, date| range.cover?(date) })
        end.sort_by { |row| [ row.finish || Date::Infinity.new, row.work.title.downcase ] }
      end
    end

    # The column a date falls in (1 to the number of weeks), held to the edges.
    def column(date) = ((date - range.first).to_i / 7 + 1).clamp(1, weeks.size)
    def before?(date) = date < range.first
    def after?(date) = date > range.last
    def today_column = (column(Date.current) if range.cover?(Date.current))

    private
      def works
        scope = Work.open.includes(:client)
        scope = scope.where(client: @client) if @client
        scope = scope.where(id: @work.id) if @work
        scope = scope.where(id: Task.open.assigned_to(@person).select(:work_id)) if @person
        scope.to_a
      end
  end
end
