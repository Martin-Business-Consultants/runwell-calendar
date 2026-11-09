module Calendar
  # Time off: anyone adds and removes their own; whoever may manage time off (owners and managers)
  # does anyone's. No approval: it records who's away.
  class TimeOffsController < ApplicationController
    allow_staff
    agent_tool :list_time_off, on: :index, title: "List who's out",
      description: "Time off from today on (or from `from` to `to`, dates), soonest first. person: me, anyone (default), or someone's id or name. " \
        "Notes show only for your own time off, or everyone's if you may manage time off.",
      params: { person: "string", from: "date", to: "date" }
    agent_tool :add_time_off, on: :create, title: "Add time off",
      description: "Someone out: whole days from starts_on to ends_on (YYYY-MM-DD; ends_on defaults to starts_on), or half of one day (half_day). " \
        "user_id: who (you by default; someone else only if you may manage time off). note: private to them and whoever manages time off.",
      params: { time_off: { user_id: "integer", starts_on: "date!", ends_on: "date", half_day: "boolean", note: "string" } },
      next_tools: %i[list_time_off list_calendar]
    agent_tool :update_time_off, on: :update, title: "Change time off",
      description: "Your own, or anyone's if you may manage time off: its days (starts_on, ends_on), half_day or note. Only what's given changes.",
      params: { time_off: { starts_on: "date", ends_on: "date", half_day: "boolean", note: "string" } },
      next_tools: %i[list_time_off list_calendar]
    agent_tool :remove_time_off, on: :destroy, title: "Remove time off",
      description: "Your own, or anyone's if you may manage time off."

    def index
      from = date_param(:from, Date.current)
      scope = Calendar::TimeOff.includes(:user).ordered
      scope = params[:to].present? ? scope.overlapping(from..date_param(:to, from)) : scope.where(ends_on: from..)
      scope = scope.where(user: filter_person) if filter_person
      @time_offs = scope.limit(200).to_a
      @page_title = "Time off"
    end

    def new
      @time_off = Calendar::TimeOff.new(user: Current.user.person, starts_on: date_param(:date, Date.current))
      @page_title = "Add time off"
    end

    def create
      @time_off = Calendar::TimeOff.new(time_off_params.merge(created_by: Current.user.person))
      @time_off.user ||= Current.user.person
      unless @time_off.manageable_by?(Current.user)
        return redirect_back fallback_location: calendar_page_path, alert: "You can add only your own time off."
      end

      if @time_off.save
        redirect_to calendar_page_path(date: @time_off.starts_on.iso8601, day: @time_off.starts_on.iso8601),
          notice: "#{@time_off.user.display_name}: out #{@time_off.span_text}#{" (half day)" if @time_off.half_day?}."
      else
        @page_title = "Add time off"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @time_off = manageable_time_off or return
      @page_title = "Change time off"
    end

    def update
      @time_off = manageable_time_off or return
      attributes = params.expect(time_off: %i[starts_on ends_on half_day note])
      attributes[:ends_on] = attributes[:starts_on] if attributes.key?(:starts_on) && attributes[:ends_on].blank?
      if @time_off.update(attributes)
        redirect_to calendar_page_path(date: @time_off.starts_on.iso8601, day: @time_off.starts_on.iso8601),
          notice: "#{@time_off.user.display_name}: out #{@time_off.span_text}#{" (half day)" if @time_off.half_day?}."
      else
        @page_title = "Change time off"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      time_off = Calendar::TimeOff.find(params[:id])
      unless time_off.manageable_by?(Current.user)
        return redirect_back fallback_location: calendar_time_offs_path, alert: "You can remove only your own time off."
      end

      time_off.destroy!
      redirect_back fallback_location: calendar_time_offs_path, notice: "Removed #{time_off.user.display_name}’s time off, #{time_off.span_text}."
    end

    private
      # The time off on screen, if the person may change it (their own, or anyone's with
      # manage_time_off); otherwise back where they came from, saying so.
      def manageable_time_off
        time_off = Calendar::TimeOff.find(params[:id])
        return time_off if time_off.manageable_by?(Current.user)

        redirect_back fallback_location: calendar_time_offs_path, alert: "You can change only your own time off."
        nil
      end

      def time_off_params
        attributes = params.expect(time_off: %i[user_id starts_on ends_on half_day note])
        attributes[:user_id] = find_person(attributes[:user_id])&.id if attributes[:user_id].present? && attributes[:user_id].to_s !~ /\A\d+\z/
        attributes
      end
  end
end
