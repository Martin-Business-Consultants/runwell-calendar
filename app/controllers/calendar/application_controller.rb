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

      # A way of seeing the calendar a person keeps (weekends shown, the day panel open): a param
      # changes it (and stays in the link), a cookie remembers it for their next visit.
      def preference(name, values)
        cookie = :"calendar_#{name}"
        cookies.permanent[cookie] = { value: params[name], same_site: :lax } if values.include?(params[name])
        params[name].presence_in(values) || cookies[cookie].presence_in(values) || values.first
      end

      def date_param(key, default = nil)
        Date.iso8601(params[key].to_s)
      rescue Date::Error
        default
      end
  end
end
