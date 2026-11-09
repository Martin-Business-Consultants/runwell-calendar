module Calendar
  # The calendar's pages use the core's layout, and vanish while it's switched off. The filters
  # every page and tool reads (person, client, work, what to show, the search) are worked out here,
  # from query params, so a filtered calendar is a link that can be bookmarked or shared.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:calendar) }

    private
      def schedule_for(range)
        Calendar::Schedule.new(range, person: filter_person, client: filter_client, work: filter_work,
          show: params[:show], query: params[:q], viewer: Current.user)
      end

      # person: "me" (whoever's asking, or the person their agent acts for), anyone (the default),
      # or someone on the team by id or name.
      def filter_person
        return @filter_person if defined?(@filter_person)

        @filter_person = find_person(params[:person])
      end

      def find_person(value)
        value = value.to_s.strip
        return nil if value.blank? || value == "anyone"
        return Current.user.person if value == "me"

        people = User.people.active
        people.find_by(id: value) || people.find_by("lower(name) = ?", value.downcase) || people.where("lower(name) LIKE ?", "%#{User.sanitize_sql_like(value.downcase)}%").first ||
          raise(ActiveRecord::RecordNotFound, "No one on the team called #{value}")
      end

      def filter_client
        return @filter_client if defined?(@filter_client)

        value = params[:client].to_s.strip
        @filter_client = value.blank? || value == "all" ? nil : (Client.find_by(id: value) || Client.find_by!(name: value))
      end

      def filter_work
        return @filter_work if defined?(@filter_work)

        value = params[:work].to_s.strip
        @filter_work = value.blank? || value == "all" ? nil : Work.find_by_ref!(value)
      end

      # Undo for a drag: how the task stood before it (its date, who was on it, where it sat in its
      # day), signed so it can't be altered, good for 15 minutes; offer_undo puts it in the flash
      # with what happened, for the page the drop refreshes to (calendars/_undo).
      def remember_undo(task)
        neighbours = task.due_on ? Calendar::Schedule.new(task.due_on..task.due_on, viewer: Current.user).on(task.due_on).select(&:task?).map { it.record.id } : []
        after = neighbours.index(task.id)&.then { neighbours[it + 1] }
        @undo = Rails.application.message_verifier("calendar_undo").generate(
          { "task_id" => task.id, "due_on" => task.due_on&.iso8601, "owner_ids" => task.owners.map(&:id), "before" => after }, expires_in: 15.minutes)
      end

      def offer_undo(text)
        flash[:calendar_undo] = { "text" => text, "token" => @undo } if @undo
      end

      def date_param(key, default = nil)
        Date.iso8601(params[key].to_s)
      rescue Date::Error
        default
      end
  end
end
