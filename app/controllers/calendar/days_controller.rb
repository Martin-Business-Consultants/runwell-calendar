module Calendar
  # One day: who's out, what's due (and overdue, on today), the dates on it and how loaded each
  # person is. The page is the calendar with that day open; agents read it as JSON.
  class DaysController < ApplicationController
    allow_staff
    agent_tool :show_calendar_day, on: :show, title: "Read one day of the calendar",
      description: "date: YYYY-MM-DD. Who's out, tasks due (with who's on each and any clash: someone on it who's out), " \
        "overdue tasks when it's today, date fields on it (a launch), work closed, and how many open tasks each person has due. " \
        "Takes the calendar's filters: person, client, work, show, q.",
      params: { person: "string", client: "string", work: "string", show: Calendar::Schedule::SHOWS.keys, q: "string" },
      next_tools: %i[add_time_off list_calendar]

    def show
      @date = date_param(:date) or raise ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to calendar_page_path(request.query_parameters.except("date").merge(date: @date.iso8601, day: @date.iso8601)) }
        format.json { @schedule = schedule_for(@date..@date) }
      end
    end
  end
end
