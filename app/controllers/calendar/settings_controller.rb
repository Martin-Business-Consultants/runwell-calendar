module Calendar
  # Settings › Plugins › Calendar, for whoever manages settings: how many open tasks due in a day is
  # too many for one person, the Monday look-ahead, and holidays (added here, or read from a public
  # holiday calendar's link, nightly and when it's saved).
  class SettingsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :show_calendar_settings, on: :show, title: "Show the calendar's settings",
      description: "The workload limit (open tasks due in a day before someone counts as overloaded), whether the Monday look-ahead goes out, the holiday calendar followed and the holidays coming up."
    agent_tool :update_calendar_settings, on: :update, title: "Change the calendar's settings",
      description: "workload_limit: 1 to 50 open tasks due in a day before someone counts as overloaded. look_ahead: email everyone their week each Monday. holidays_url: a public holiday calendar's .ics link (https://), read nightly; blank to stop following one.",
      params: { setting: { workload_limit: "integer", look_ahead: "boolean", holidays_url: "string" } }, next_tools: %i[show_calendar_settings]

    def show
      @setting = Calendar::Setting.current
      @holidays = Calendar::Holiday.upcoming.ordered.limit(60)
    end

    def update
      @setting = Calendar::Setting.current
      url_was = @setting.holidays_url
      if @setting.update(params.expect(setting: %i[workload_limit look_ahead holidays_url]))
        Calendar::SyncJob.perform_later if @setting.holidays_url != url_was
        redirect_to calendar_settings_path, notice: "The calendar’s settings are saved#{"; reading the holiday calendar now" if @setting.holidays_url.present? && @setting.holidays_url != url_was}."
      else
        @holidays = Calendar::Holiday.upcoming.ordered.limit(60)
        render :show, status: :unprocessable_entity
      end
    end
  end
end
