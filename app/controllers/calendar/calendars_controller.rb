module Calendar
  # The calendar: a month, week or agenda of everything dated (Calendar::Schedule), with the day
  # picked (?day=) open beside it. For agents, list_calendar reads any range of days.
  class CalendarsController < ApplicationController
    MAX_DAYS = 92

    allow_staff
    agent_tool :list_calendar, on: :show, title: "Read the calendar: who's out, what's due and every date",
      description: "Day by day from `from` to `to` (dates, YYYY-MM-DD; default today and the 13 days after; at most #{MAX_DAYS} days): " \
        "tasks by due date (open, overdue or done, with who's on each, and whether each is movable), who's out (time off, holidays for everyone, " \
        "all-day busy from people's own calendars), every date field you may see " \
        "(a piece of work's launch, a client's renewal) and work closed. A clash is someone on a task or a piece of work who's out that day. " \
        "person: me, anyone (default), or someone's id or name; client: an id or name; work: a ref; " \
        "show: all, open, overdue, done, time_off, dates or closed; q: a search (fuzzy: typos and partial words) across clients, work, tasks and people. " \
        "Overdue tasks are listed too when the range includes today.",
      params: { from: "date", to: "date", person: "string", client: "string", work: "string", show: Calendar::Schedule::SHOWS.keys, q: "string" },
      next_tools: %i[show_calendar_day add_time_off]

    def show
      respond_to do |format|
        format.html do
          @preferences = Calendar::Preferences.new(params, cookies)
          @drawer = drawer if @preferences.drawer?
          @period = Calendar::Period.new(view: params[:view], date: date_param(:date), weekends: @preferences.weekends?)
          @day = date_param(:day) || (@period.includes_today? ? Date.current : @period.range.first)
          @schedule = schedule_for(@period.range.cover?(@day) ? @period.range : [ @period.range.first, @day ].min..[ @period.range.last, @day ].max)
          @timeline = Calendar::Timeline.new(@period.range, client: filter_client, work: filter_work, person: filter_person, viewer: Current.user) if @period.timeline?
          @page_title = "Calendar"
        end
        format.json do
          from = date_param(:from, Date.current)
          to = [ date_param(:to, from + 13), from + (MAX_DAYS - 1) ].min
          to = from if to < from
          @schedule = schedule_for(from..to)
        end
      end
    end

    private
      # The tasks drawer, from its own params (tasks_*), apart from the calendar's filters.
      def drawer
        owner = case params[:tasks_owner].to_s
        when "", "anyone" then nil
        when "none" then :nobody
        else find_person(params[:tasks_owner])
        end
        client = params[:tasks_client].presence_in([ nil, "all" ]) ? nil : Client.find_by(id: params[:tasks_client])
        work = params[:tasks_work].presence_in([ nil, "all" ]) ? nil : Work.find_by(ref: params[:tasks_work])
        Calendar::Drawer.new(due: params[:tasks_due], owner: owner, client: client, work: work, query: params[:tasks_q])
      end
  end
end
