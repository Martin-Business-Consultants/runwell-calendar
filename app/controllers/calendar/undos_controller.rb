module Calendar
  # Undo after a drag on the calendar: the task put back as it stood (its date, who was on it,
  # where it sat in its day), from the signed note the drop left (ApplicationController#remember_undo).
  class UndosController < ApplicationController
    allow_staff
    agent_exempt :create, reason: "undoes a drag in the browser; update_task changes a task back"

    def create
      before = Rails.application.message_verifier("calendar_undo").verified(params[:token].to_s)
      return redirect_back(fallback_location: calendar_page_path, alert: "That can’t be undone any more.") unless before

      task = Task.find(before["task_id"])
      owners = Array(before["owner_ids"])
      task.update!(due_on: before["due_on"], owner_id: owners.first, other_owner_ids: owners.drop(1))
      Calendar::Placement.place!(task, before: before["before"])
      redirect_back fallback_location: calendar_page_path, notice: "#{task.title} is back as it was."
    end
  end
end
