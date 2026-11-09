module Calendar
  # A day off for everyone, added or removed by hand in the calendar's settings (those read from the
  # holiday calendar come and go with it).
  class HolidaysController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :add_holiday, on: :create, title: "Add a holiday (everyone's day off)",
      description: "date (YYYY-MM-DD) and name. Everyone counts as out that day, so tasks or launches due then are flagged.",
      params: { holiday: { date: "date!", name: "string!" } }, next_tools: %i[show_calendar_settings]
    agent_tool :remove_holiday, on: :destroy, title: "Remove a holiday added by hand"

    def create
      holiday = Calendar::Holiday.new(params.expect(holiday: %i[date name]).merge(source: "manual"))
      if holiday.save
        redirect_to calendar_settings_path, notice: "#{holiday.name}, #{l(holiday.date, format: :long)}, is a day off for everyone."
      else
        redirect_to calendar_settings_path, alert: holiday.errors.full_messages.to_sentence
      end
    end

    def destroy
      holiday = Calendar::Holiday.find(params[:id])
      return redirect_to(calendar_settings_path, alert: "#{holiday.name} comes from the holiday calendar; stop following it to remove it.") unless holiday.manual?

      holiday.destroy!
      redirect_to calendar_settings_path, notice: "Removed #{holiday.name}."
    end
  end
end
