module Calendar
  # A task dragged in the team view: to another day (due then), another person's row (handed from
  # the row it came from to this one: replaced among those on it, keeping the rest and who leads
  # unless it was the lead) or the Nobody yet row (taken off whoever's row it came from), and where
  # it was let go among that day's tasks. The id it's sent with is "task-from" (from: a user's id, or
  # "none"). Through the task's own update, so its history and live refreshes are the core's.
  class TeamDropsController < ApplicationController
    allow_staff
    agent_exempt :create, reason: "dragging a task in the calendar's team view; update_task sets due_on, owner_id and other_owner_ids"

    def create
      task_id, from = params[:task_id].to_s.split("-", 2)
      task = Task.find(task_id)
      date = date_param(:date) or raise ActiveRecord::RecordNotFound
      to = params[:user_id] == "none" ? nil : User.people.active.find(params[:user_id])

      if Calendar::TaskRules.movable?(task)
        remember_undo(task)
        owners = handed(task.owners.map(&:id), from: (from == "none" ? nil : from.to_i), to: to&.id)
        if task.update(due_on: date, owner_id: owners.first, other_owner_ids: owners.drop(1))
          Calendar::Placement.place!(task, before: params[:before])
          offer_undo("#{task.title}: due #{l(date, format: "%a %b %-d")}#{", #{to ? "on #{to.display_name}" : "nobody on it"}" if from.to_s != (to&.id || "none").to_s}")
        end
      end

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
        format.html { redirect_back fallback_location: calendar_page_path(view: "team", date: date.iso8601) }
      end
    end

    private
      # Those on it after the hand-over: from out, to in its place (or at the end); to nil takes
      # from off; from nil (Nobody yet) gives it to `to`.
      def handed(owners, from:, to:)
        return owners if from == to

        at = owners.index(from)
        owners = owners - [ from ] if from
        return owners unless to
        return owners if owners.include?(to)

        at ? owners.insert(at, to) : owners + [ to ]
      end
  end
end
