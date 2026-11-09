module Calendar
  # Reads an iCalendar file (RFC 5545: a Google, Outlook or Apple calendar's private link, a public
  # holiday calendar) into the events inside a window of dates: all-day ones by their dates, timed
  # ones by their start and end in the install's zone. Repeating events are expanded within the
  # window for the rules calendars use most (daily, weekly or monthly; INTERVAL, BYDAY, COUNT,
  # UNTIL) with their exceptions (EXDATE); rarer rules show their first occurrence only. Cancelled
  # events are left out; free ones (TRANSP:TRANSPARENT) are marked so.
  class IcsReader
    Event = Data.define(:title, :starts_on, :ends_on, :starts_at, :ends_at, :all_day, :free)
    DAYS = { "MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "SA" => 6, "SU" => 0 }.freeze
    MAX_OCCURRENCES = 20_000

    def initialize(text, window:)
      @text, @window = text.to_s, window
    end

    def events
      vevents.flat_map { |properties| occurrences(properties) }.select { overlaps?(it) }
    end

    private
      # Lines unfolded (a line starting with a space or tab continues the one before), then each
      # VEVENT's properties as name → [params, value] (EXDATE may repeat, so it's a list).
      def vevents
        lines = @text.gsub(/\r?\n[ \t]/, "").split(/\r?\n/)
        events, current = [], nil
        lines.each do |line|
          case line
          when "BEGIN:VEVENT" then current = { "EXDATE" => [] }
          when "END:VEVENT" then (events << current if current) && (current = nil)
          else
            next unless current && (match = line.match(/\A([A-Z-]+)((?:;[^:]*)?):(.*)\z/))

            name, params, value = match[1], match[2].delete_prefix(";").split(";").to_h { it.split("=", 2) }, match[3]
            name == "EXDATE" ? current["EXDATE"].concat(value.split(",").map { [ params, it ] }) : (current[name] ||= [ params, value ])
          end
        end
        events.reject { it["STATUS"]&.last == "CANCELLED" || it["DTSTART"].nil? }
      end

      def occurrences(properties)
        start = moment(*properties["DTSTART"])
        return [] unless start

        finish = properties["DTEND"] ? moment(*properties["DTEND"]) : nil
        all_day = start.is_a?(Date) && !start.is_a?(DateTime)
        length = finish ? (finish - start) : (all_day ? 1 : 0)
        title = unescape(properties["SUMMARY"]&.last.to_s).presence || "Busy"
        free = properties["TRANSP"]&.last == "TRANSPARENT"
        excluded = properties["EXDATE"].filter_map { |params, value| moment(params, value) }.map { day_of(it) }.to_set

        starts(start, properties["RRULE"]&.last).reject { excluded.include?(day_of(it)) }.map do |first|
          event(title, first, first + length, all_day, free)
        end
      end

      def event(title, starts, ends, all_day, free)
        if all_day
          Event.new(title: title, starts_on: starts, ends_on: [ ends - 1, starts ].max, starts_at: nil, ends_at: nil, all_day: true, free: free)
        else
          Event.new(title: title, starts_on: starts.to_date, ends_on: [ ends, starts ].max.to_date, starts_at: starts, ends_at: ends, all_day: false, free: free)
        end
      end

      # Each start of a repeating event near the window (or the one start of a single event). COUNT
      # counts from the first; only those within a month of the window are kept, so a meeting that's
      # repeated daily for years still reaches today.
      def starts(start, rule)
        return [ start ] if rule.blank?

        parts = rule.split(";").to_h { it.split("=", 2) }
        interval = [ parts["INTERVAL"].to_i, 1 ].max
        count = parts["COUNT"]&.to_i
        until_day = parts["UNTIL"] && moment({}, parts["UNTIL"])&.then { day_of(it) }
        last_day = [ @window.last, until_day ].compact.min
        from = @window.first - 31
        weekdays = parts["BYDAY"].to_s.split(",").filter_map { DAYS[it.gsub(/[^A-Z]/, "")] }

        seen, kept = 0, []
        each_candidate(start, parts["FREQ"], interval, weekdays) do |candidate|
          day = day_of(candidate)
          break if day > last_day || (count && seen >= count) || seen >= MAX_OCCURRENCES

          seen += 1
          kept << candidate if day >= from
        end
        kept
      end

      def each_candidate(start, frequency, interval, weekdays)
        step = ->(date, n) { date.is_a?(Date) && !date.is_a?(DateTime) ? date + n : date + n.days }
        case frequency
        when "DAILY"
          (0..).each { |n| yield step.(start, n * interval) }
        when "WEEKLY"
          days = weekdays.presence || [ day_of(start).wday ]
          week_start = step.(start, -day_of(start).wday)
          (0..).each do |week|
            base = step.(week_start, week * 7 * interval)
            days.sort.each do |wday|
              candidate = step.(base, wday)
              yield candidate unless day_of(candidate) < day_of(start)
            end
          end
        when "MONTHLY"
          (0..).each { |n| yield(start.is_a?(Date) && !start.is_a?(DateTime) ? start >> (n * interval) : start + (n * interval).months) }
        else
          yield start
        end
      end

      # A DTSTART / DTEND / EXDATE value: a Date for VALUE=DATE (or a bare yyyymmdd), else a time in
      # the install's zone (UTC with a Z, the event's TZID, or the install's own).
      def moment(params, value)
        value = value.to_s.strip
        return Date.strptime(value[0, 8], "%Y%m%d") if params["VALUE"] == "DATE" || value.match?(/\A\d{8}\z/)

        if value.end_with?("Z")
          Time.find_zone("UTC").strptime(value, "%Y%m%dT%H%M%SZ").in_time_zone
        else
          zone = (params["TZID"] && Time.find_zone(params["TZID"])) || Time.zone
          zone.strptime(value, "%Y%m%dT%H%M%S").in_time_zone
        end
      rescue ArgumentError, Date::Error
        nil
      end

      def day_of(moment) = moment.respond_to?(:to_date) ? moment.to_date : moment
      def overlaps?(event) = event.starts_on <= @window.last && event.ends_on >= @window.first
      def unescape(text) = text.gsub("\\n", " ").gsub(/\\([,;\\])/, '\1').squish
  end
end
