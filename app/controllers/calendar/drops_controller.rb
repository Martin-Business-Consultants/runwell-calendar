module Calendar
  # An open task dragged to another day on the calendar: due that day now, through the task's own
  # update (its history and live refreshes are the core's). The page refreshes in place.
  class DropsController < ApplicationController
    allow_staff
    agent_exempt :create, reason: "dragging a task to another day on the calendar; update_task sets due_on"

    def create
      task = Task.find(params[:task_id])
      date = date_param(:date) or raise ActiveRecord::RecordNotFound
      task.update(due_on: date) unless task.status == "done"

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
        format.html { redirect_back fallback_location: calendar_page_path(date: date.iso8601), notice: "#{task.title} is due #{l(date, format: :long)}." }
      end
    end
  end
end
