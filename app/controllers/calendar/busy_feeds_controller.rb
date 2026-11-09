module Calendar
  # Connecting your own calendar (Google, Outlook, Apple) by its private link, so the calendar knows
  # when you're busy. That link is a key to your calendar: only you set or remove it, in the browser.
  class BusyFeedsController < ApplicationController
    allow_staff
    browser_only :update, :destroy, reason: "a private calendar link is a key to someone's calendar: only its person connects or removes it, in the browser"

    def update
      feed = Calendar::BusyFeed.find_or_initialize_by(user: Current.user.person)
      if feed.update(url: params.expect(busy_feed: [ :url ])[:url])
        Calendar::SyncJob.perform_later(feed)
        redirect_to calendar_feed_path, notice: "Your calendar is connected; reading it now. Busy days show as out, meetings as busy."
      else
        redirect_to calendar_feed_path, alert: feed.errors.full_messages.to_sentence
      end
    end

    def destroy
      Calendar::BusyFeed.where(user: Current.user.person).destroy_all
      Calendar::BusyEvent.where(user: Current.user.person).delete_all
      redirect_to calendar_feed_path, notice: "Your calendar is disconnected, and what was read from it is gone."
    end
  end
end
