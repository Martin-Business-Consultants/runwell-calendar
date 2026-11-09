module Calendar
  # The calendar's view helpers, prefixed calendar_ since they're mixed into every view.
  module CalendarHelper
    # How many things a month's day shows before "+3 more".
    CALENDAR_DAY_LIMIT = 3

    # The calendar's address with some params changed and the rest (filters, search) kept.
    def calendar_link(**changes)
      calendar_page_path(request.query_parameters.merge(changes.transform_keys(&:to_s)).reject { |_, value| value.blank? })
    end

    # A link that opens a day: in the panel beside the calendar (its frame, advancing the address),
    # or, with the panel closed, the page with it opened. Built here, in Ruby: a data hash worked out
    # in a template is written by Herb as a literal attribute.
    def calendar_day_link_to(content, date, panel:, **options)
      return link_to(content, calendar_link(day: date.iso8601, panel: Calendar::Preferences.on(:panel)), **options) unless panel

      link_to(content, calendar_link(day: date.iso8601), data: { turbo_frame: "calendar_day", turbo_action: "advance" }, **options)
    end

    def calendar_person_options
      [ [ "Anyone", "anyone" ], [ "Me", "me" ] ] + User.people.active.ordered.map { [ it.display_name, it.id.to_s ] }
    end

    def calendar_client_options
      [ [ "All #{term(:client, count: 2).downcase}", "all" ] ] + Client.active.ordered.map { [ it.name, it.id.to_s ] }
    end

    def calendar_work_options
      [ [ "All #{term(:work).downcase}", "all" ] ] + Work.open.order(:title).map { [ it.title, it.ref ] }
    end

    def calendar_show_options = Calendar::Schedule::SHOWS.map { |value, text| [ text, value ] }

    # The tasks drawer's choices: when they're due, and who's on them (nobody: not taken on yet).
    def calendar_drawer_due_options = Calendar::Drawer::DUES.map { |value, text| [ text, value ] }

    def calendar_drawer_owner_options
      [ [ "Anyone", "anyone" ], [ "Me", "me" ], [ "Nobody yet", "none" ] ] + User.people.active.ordered.map { [ it.display_name, it.id.to_s ] }
    end

    # Who can be given time off by the person on screen: themselves, or anyone if they may manage it.
    def calendar_time_off_people
      can?(:manage_time_off) ? User.people.active.ordered.map { [ it.display_name, it.id ] } : [ [ Current.user.person.display_name, Current.user.person.id ] ]
    end

    # "Tuesday, November 10" (with the year when it isn't this one).
    def calendar_day_title(date)
      l(date, format: date.year == Date.current.year ? "%A, %B %-d" : "%A, %B %-d, %Y")
    end

    def calendar_record_path(record)
      case record
      when Task then task_path(record)
      when Work then work_path(record)
      when Client then client_path(record)
      end
    end

    # A person, for agents: their id and name.
    def calendar_person_json(user) = user && { "id" => user.id, "name" => user.display_name }

    # Who's out when it lands, in words: "Priya is out" or "Priya and Marcus are out".
    def calendar_clash_text(people)
      names = people.map(&:display_name)
      "#{names.to_sentence} #{names.one? ? "is" : "are"} out"
    end
  end
end
