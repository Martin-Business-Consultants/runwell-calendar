module Calendar
  # Each night: every connected calendar and the holiday calendar read again, and on Monday (in the
  # install's zone, once) the week's look-ahead sent to everyone with something in it.
  class NightlyJob < ApplicationJob
    def perform
      return unless Runwell::Plugins.enabled?(:calendar)

      Calendar::BusyFeed.find_each { Calendar::SyncJob.perform_later(it) }
      Calendar::SyncJob.perform_later
      Calendar::LookAhead.send_this_week
    end
  end
end
