module Calendar
  # Who's out, what's due and every date that matters, on one calendar (README.md). It owns its
  # tables (calendar_time_offs, calendar_feeds), points at core records by id, and reaches the core
  # only through the plugin contract (docs/plugin-contract.md in Runwell). Remove it and Runwell
  # runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as calendar_*), so the core layout's helpers work.
    initializer "calendar.routes" do |app|
      app.routes.append do
        scope "calendar", module: "calendar", as: "calendar" do
          get "/", to: "calendars#show", as: :page
          get "days/:date", to: "days#show", as: :day, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
          post "days/:date/drops/:task_id", to: "drops#create", as: :day_drop, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
          post "drawer/drops/:task_id", to: "drops#destroy", as: :drawer_drop
          post "team/:user_id/:date/drops/:task_id", to: "team_drops#create", as: :team_drop, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
          resource :undo, only: :create
          resource :settings, only: %i[show update]
          resources :holidays, only: %i[create destroy]
          resource :busy_feed, path: "busy", only: %i[update destroy]
          resources :time_offs, path: "time-off", only: %i[index new create edit update destroy]
          resource :feed, path: "subscribe", only: %i[show create destroy]
          get "feed/:token", to: "subscriptions#show", as: :subscription, format: true, constraints: { format: "ics" }
        end
      end
    end

    initializer "calendar.models" do
      ActiveSupport.on_load(:runwell_user) { has_many :calendar_time_offs, class_name: "Calendar::TimeOff", dependent: :delete_all }
      ActiveSupport.on_load(:runwell_task) { has_one :calendar_placement, class_name: "Calendar::Placement", dependent: :delete }
    end

    initializer "calendar.helpers" do
      ActiveSupport.on_load(:action_view) { include Calendar::CalendarHelper }
    end

    config.to_prepare do
      Runwell::Plugins.register :calendar, name: "Calendar", version: Calendar::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 5.8.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-calendar",
        description: "Who's out, what's due and every date that matters, on one calendar: tasks by due date, time off, launches and other date fields, and work closed, with the clashes (someone out when their task or launch lands). Filters, fuzzy search, a private feed for Google Calendar or Outlook, and tools for AI."
      Runwell::Plugins.nav :calendar, "Calendar", -> { calendar_page_path }, icon: "calendar"
      Runwell::Plugins.permission :calendar, :manage_time_off, name: "Add and remove anyone’s time off", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :calendar, "calendar/calendar"
      Runwell::Plugins.settings :calendar, "Calendar", -> { calendar_settings_path if can?(:manage_settings) }
      Runwell::Plugins.nightly :calendar, -> { Calendar::NightlyJob.perform_later }
      # Who's away when, for the task owner picker's Out: time off and all-day busy per person,
      # holidays for everyone.
      Runwell::Plugins.away :calendar, ->(range) {
        away = Hash.new { |hash, key| hash[key] = [] }
        Calendar::TimeOff.overlapping(range).find_each { |off| away[off.user_id].concat(off.days.to_a) }
        Calendar::BusyEvent.overlapping(range).where(all_day: true).find_each { |event| away[event.user_id].concat((event.starts_on..event.ends_on).to_a) }
        away[:everyone] = Calendar::Holiday.between(range).pluck(:date)
        away
      }
      Runwell::Plugins.slot :task_notice, :calendar, "calendar/slots/task_notice"
      Runwell::Plugins.slot :portal_home, :calendar, "calendar/slots/portal_home"
      Runwell::Plugins.shortcut :calendar, "h", "Calendar: the previous month, week or four weeks"
      Runwell::Plugins.shortcut :calendar, "l", "Calendar: the next month, week or four weeks"
      Runwell::Plugins.shortcut :calendar, "t", "Calendar: today"
      Runwell::Plugins.shortcut :calendar, "]", "Calendar: show or hide the day panel"
      Runwell::Plugins.shortcut :calendar, "r", "Calendar: show or hide the tasks drawer"
      Runwell::Plugins.shortcut :calendar, "mod+z", "Calendar: undo the last drag"
    end
  end
end
