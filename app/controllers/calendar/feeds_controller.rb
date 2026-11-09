module Calendar
  # Subscribe: a person's private link to the calendar, for Google Calendar, Outlook or Apple's.
  # Made, reset and turned off only by its person, in the browser: a link that reads the calendar
  # is a key, and an agent's token can't mint one.
  class FeedsController < ApplicationController
    allow_staff
    agent_exempt :show, reason: "the person's own page for their private calendar link"
    browser_only :create, :destroy, reason: "a calendar link is a key to the calendar: only its person makes, resets or turns it off, in the browser"

    def show
      @feed = Calendar::Feed.find_by(user: Current.user.person)
      @page_title = "Subscribe"
    end

    # Shows the new link once, here: only its digest is kept.
    def create
      @feed = Calendar::Feed.issue!(Current.user.person)
      @page_title = "Subscribe"
      flash.now[:notice] = "Here’s your calendar link. Copy it now: it’s shown only once."
      render :show
    end

    def destroy
      Calendar::Feed.where(user: Current.user.person).destroy_all
      redirect_to calendar_feed_path, notice: "Your calendar link is off. Calendars subscribed to it stop updating."
    end
  end
end
