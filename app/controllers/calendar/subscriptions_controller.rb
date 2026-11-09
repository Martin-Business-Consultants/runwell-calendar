module Calendar
  # The .ics a calendar app subscribes to, at a private link (Calendar::Feed): no sign-in, found by
  # its token, never an id. Read as the link's person: their open tasks with a due date, everyone's
  # time off and the dates they may see.
  class SubscriptionsController < ::ApplicationController
    allow_unauthenticated_access

    def show
      return head(:not_found) unless Runwell::Plugins.enabled?(:calendar)

      feed = Calendar::Feed.find_by_token(params[:token]) or return head(:not_found)
      feed.fetched!
      send_data Calendar::Ics.new(feed.user, host: Runwell.host).to_s, type: "text/calendar; charset=utf-8", disposition: "inline", filename: "runwell.ics"
    end
  end
end
