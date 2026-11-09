module Calendar
  # A person's calendar as iCalendar (RFC 5545) for their private feed: all-day events for their
  # open tasks with a due date, everyone's time off and every date field they may see, from a month
  # back to six months ahead. Each event keeps its UID across fetches, so a calendar app updates it
  # in place rather than adding it again.
  class Ics
    BACK = 1.month
    AHEAD = 6.months

    def initialize(user, host:)
      @user, @host = user, host
      @range = (Date.current - BACK)..(Date.current + AHEAD)
    end

    def to_s
      lines = [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Runwell//Calendar #{Calendar::VERSION}//EN", "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH", "X-WR-CALNAME:#{escape("Runwell · #{@user.display_name}")}", "X-PUBLISHED-TTL:PT1H" ]
      events.each { lines.concat(event(**it)) }
      lines << "END:VCALENDAR"
      lines.map { fold(it) }.join("\r\n") + "\r\n"
    end

    private
      def events
        tasks + time_off + dates
      end

      def tasks
        Task.open.assigned_to(@user).where(due_on: @range).includes(:work, :client).map do |task|
          { uid: "task-#{task.id}", starts: task.due_on, ends: task.due_on, summary: task.title,
            description: [ task.work&.title, task.client&.name ].compact.uniq.join(" · "), url: url(:task_path, task) }
        end
      end

      def time_off
        Calendar::TimeOff.overlapping(@range).includes(:user).map do |off|
          { uid: "time-off-#{off.id}", starts: off.starts_on, ends: off.ends_on,
            summary: "#{off.user.display_name}: #{off.label.downcase}", description: (off.note if off.note_visible_to?(@user)), url: nil }
        end
      end

      def dates
        CustomField.dates_between(@range, viewer: @user).map do |record, field, date|
          { uid: "date-#{record.class.name.downcase}-#{record.id}-#{field.key}", starts: date, ends: date,
            summary: "#{field.label}: #{record.try(:title) || record.try(:name)}", description: nil, url: record_url(record) }
        end
      end

      def event(uid:, starts:, ends:, summary:, description:, url:)
        [ "BEGIN:VEVENT", "UID:#{uid}@#{@host}", "DTSTAMP:#{Time.current.utc.strftime("%Y%m%dT%H%M%SZ")}",
          "DTSTART;VALUE=DATE:#{starts.strftime("%Y%m%d")}", "DTEND;VALUE=DATE:#{(ends + 1).strftime("%Y%m%d")}",
          "SUMMARY:#{escape(summary)}", ("DESCRIPTION:#{escape(description)}" if description.present?),
          ("URL:#{url}" if url), "TRANSP:TRANSPARENT", "END:VEVENT" ].compact
      end

      def record_url(record)
        case record
        when Task then url(:task_path, record)
        when Work then url(:work_path, record)
        when Client then url(:client_path, record)
        end
      end

      def url(helper, record)
        "#{Runwell.protocol}://#{Runwell.host}#{Rails.application.routes.url_helpers.public_send(helper, record)}"
      end

      # Text values escape backslashes, semicolons, commas and newlines.
      def escape(text) = text.to_s.gsub("\\", "\\\\\\\\").gsub(";", "\\;").gsub(",", "\\,").gsub(/\r?\n/, "\\n")

      # Lines longer than 75 octets continue on the next, after a space.
      def fold(line)
        return line if line.bytesize <= 75

        parts, current = [], +""
        line.each_char do |char|
          if (current + char).bytesize > (parts.empty? ? 75 : 74)
            parts << current
            current = +""
          end
          current << char
        end
        parts << current
        parts.join("\r\n ")
      end
  end
end
