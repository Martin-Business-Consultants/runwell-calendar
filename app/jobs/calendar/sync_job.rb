module Calendar
  # Reads calendars from outside in the background: a person's own (busy_feed) or the public holiday
  # calendar (no argument), so a request never waits on someone else's server.
  class SyncJob < ApplicationJob
    def perform(busy_feed = nil)
      return unless Runwell::Plugins.enabled?(:calendar)

      busy_feed ? busy_feed.sync! : Calendar::Setting.current.sync_holidays!
    end
  end
end
