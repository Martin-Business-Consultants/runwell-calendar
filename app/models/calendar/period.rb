module Calendar
  # The stretch of days the calendar shows: a month (whole weeks around it), a week, the team's week
  # (a row per person), an agenda of the four weeks from a day, or a timeline of the 26 weeks from
  # the start of a month (each piece of work from its start to its dates). Weeks start on the install's first day of the week
  # (Date.beginning_of_week, Monday unless set otherwise). With weekends off, the grid's rows leave
  # out Saturdays and Sundays (the range, and so what's gathered, still covers them).
  class Period
    VIEWS = { "month" => "Month", "week" => "Week", "team" => "Team", "agenda" => "Agenda", "timeline" => "Timeline" }.freeze
    AGENDA_DAYS = 28
    TIMELINE_WEEKS = 26

    attr_reader :view, :anchor

    def initialize(view:, date:, weekends: true)
      @view = view.presence_in(VIEWS.keys) || "month"
      @anchor = date || Date.current
      @weekends = weekends
    end

    def weekends? = @weekends
    def self.weekend?(date) = date.saturday? || date.sunday?

    def range
      case view
      when "week", "team" then anchor.beginning_of_week..anchor.end_of_week
      when "agenda" then anchor..(anchor + (AGENDA_DAYS - 1))
      when "timeline" then anchor.beginning_of_month.beginning_of_week..(anchor.beginning_of_month.beginning_of_week + (TIMELINE_WEEKS * 7 - 1))
      else anchor.beginning_of_month.beginning_of_week..anchor.end_of_month.end_of_week
      end
    end

    def weeks = range.each_slice(7).map { |week| shown(week) }
    def grid? = view.in?(%w[month week])
    def team? = view == "team"
    def timeline? = view == "timeline"
    def weekdays = shown(range.first(7))

    def previous = shift(-1)
    def following = shift(1)

    # A day outside the month in focus (the leading and trailing days of a month view).
    def outside?(date) = view == "month" && date.month != anchor.month

    def includes_today? = range.cover?(Date.current)

    # "November 2026", "Nov 9 – 15, 2026" or "Nov 9 – Dec 6, 2026".
    def title
      return I18n.l(anchor, format: "%B %Y") if view == "month"
      return "#{I18n.l(range.first, format: "%b %Y")} – #{I18n.l(range.last, format: "%b %Y")}" if timeline?

      first, last = range.first, range.last
      start = I18n.l(first, format: "%b %-d")
      finish = I18n.l(last, format: first.month == last.month ? "%-d" : "%b %-d")
      "#{start} – #{finish}, #{last.year}"
    end

    private
      def shown(days) = weekends? ? days : days.reject { self.class.weekend?(it) }

      def shift(step)
        case view
        when "week", "team" then anchor + (7 * step)
        when "agenda" then anchor + (AGENDA_DAYS * step)
        when "timeline" then (anchor + (step * 3).months).beginning_of_month
        else (anchor + step.months).beginning_of_month
        end
      end
  end
end
