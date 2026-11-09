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
          resources :time_offs, path: "time-off", only: %i[index new create destroy]
          resource :feed, path: "subscribe", only: %i[show create destroy]
          get "feed/:token", to: "subscriptions#show", as: :subscription, format: true, constraints: { format: "ics" }
        end
      end
    end

    initializer "calendar.models" do
      ActiveSupport.on_load(:runwell_user) { has_many :calendar_time_offs, class_name: "Calendar::TimeOff", dependent: :delete_all }
    end

    initializer "calendar.helpers" do
      ActiveSupport.on_load(:action_view) { include Calendar::CalendarHelper }
    end

    config.to_prepare do
      Runwell::Plugins.register :calendar, name: "Calendar", version: Calendar::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 5.5.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-calendar",
        description: "Who's out, what's due and every date that matters, on one calendar: tasks by due date, time off, launches and other date fields, and work closed, with the clashes (someone out when their task or launch lands). Filters, fuzzy search, a private feed for Google Calendar or Outlook, and tools for AI."
      Runwell::Plugins.nav :calendar, "Calendar", -> { calendar_page_path }, icon: "calendar"
      Runwell::Plugins.permission :calendar, :manage_time_off, name: "Add and remove anyone’s time off", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :calendar, "calendar/calendar"
      Runwell::Plugins.shortcut :calendar, "h", "Calendar: the previous month, week or four weeks"
      Runwell::Plugins.shortcut :calendar, "l", "Calendar: the next month, week or four weeks"
      Runwell::Plugins.shortcut :calendar, "t", "Calendar: today"
    end
  end
end
