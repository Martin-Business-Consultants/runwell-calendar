module Calendar
  # The stretch of days the calendar shows: a month (whole weeks around it), a week, or an agenda
  # of the four weeks from a day. Weeks start on the install's first day of the week
  # (Date.beginning_of_week, Monday unless set otherwise).
  class Period
    VIEWS = { "month" => "Month", "week" => "Week", "agenda" => "Agenda" }.freeze
    AGENDA_DAYS = 28

    attr_reader :view, :anchor

    def initialize(view:, date:)
      @view = view.presence_in(VIEWS.keys) || "month"
      @anchor = date || Date.current
    end

    def range
      case view
      when "week" then anchor.beginning_of_week..anchor.end_of_week
      when "agenda" then anchor..(anchor + (AGENDA_DAYS - 1))
      else anchor.beginning_of_month.beginning_of_week..anchor.end_of_month.end_of_week
      end
    end

    def weeks = range.each_slice(7).to_a
    def weekdays = range.first(7)

    def previous = shift(-1)
    def following = shift(1)

    # A day outside the month in focus (the leading and trailing days of a month view).
    def outside?(date) = view == "month" && date.month != anchor.month

    def includes_today? = range.cover?(Date.current)

    # "November 2026", "Nov 9 – 15, 2026" or "Nov 9 – Dec 6, 2026".
    def title
      return I18n.l(anchor, format: "%B %Y") if view == "month"

      first, last = range.first, range.last
      start = I18n.l(first, format: "%b %-d")
      finish = I18n.l(last, format: first.month == last.month ? "%-d" : "%b %-d")
      "#{start} – #{finish}, #{last.year}"
    end

    private
      def shift(step)
        case view
        when "week" then anchor + (7 * step)
        when "agenda" then anchor + (AGENDA_DAYS * step)
        else (anchor + step.months).beginning_of_month
        end
      end
  end
end
