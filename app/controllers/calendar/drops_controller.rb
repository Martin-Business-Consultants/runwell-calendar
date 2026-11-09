module Calendar
  # An open task dragged to another day on the calendar (from a day or the tasks drawer): due that
  # day now, where it was dropped among that day's tasks (before: the one it now sits above), which
  # is also how a day's tasks are rearranged; dragged into the drawer, it has no date again. Through the task's own update (its
  # history and live refreshes are the core's). The page refreshes in place.
  class DropsController < ApplicationController
    allow_staff
    agent_exempt :create, reason: "dragging a task to another day on the calendar; update_task sets due_on"
    agent_exempt :destroy, reason: "dragging a task into the calendar's tasks drawer; update_task with a blank due_on clears it"

    def create
      task = Task.find(params[:task_id])
      date = date_param(:date) or raise ActiveRecord::RecordNotFound
      if Calendar::TaskRules.movable?(task) && task.update(due_on: date)
        Calendar::Placement.place!(task, before: params[:before])
      end

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
        format.html { redirect_back fallback_location: calendar_page_path(date: date.iso8601), notice: "#{task.title} is due #{l(date, format: :long)}." }
      end
    end

    def destroy
      task = Task.find(params[:task_id])
      task.update(due_on: nil) if Calendar::TaskRules.movable?(task)

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
        format.html { redirect_back fallback_location: calendar_page_path, notice: "#{task.title} has no date now." }
      end
    end
  end
end
