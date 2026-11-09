module Calendar
  # A person's own calendar (Google, Outlook, Apple), connected by its private link to show when
  # they're busy: an all-day event they're busy for counts as out (clashes included), a meeting as
  # busy for part of the day. Only the person sees what each is called; everyone else sees "Busy".
  # The link is encrypted, read nightly and when it's saved, and only the two weeks back to three
  # months ahead are kept.
  class BusyFeed < ApplicationRecord
    self.table_name = "calendar_busy_feeds"
    WINDOW_BACK = 14
    WINDOW_AHEAD = 90

    belongs_to :user
    encrypts :url

    validates :url, format: { with: %r{\A(https|webcal)://\S+\z}i, message: "should be the calendar's private link (https:// or webcal://)" }
    normalizes :url, with: ->(url) { url.to_s.strip }

    def sync!
      window = (Date.current - WINDOW_BACK)..(Date.current + WINDOW_AHEAD)
      events = Calendar::IcsReader.new(Calendar::Fetch.get(url), window: window).events.reject(&:free)
      now = Time.current
      transaction do
        Calendar::BusyEvent.where(user_id: user_id).delete_all
        rows = events.map do |event|
          { user_id: user_id, starts_on: event.starts_on, ends_on: event.ends_on, starts_at: event.starts_at, ends_at: event.ends_at,
            all_day: event.all_day, title: event.title.truncate(120), created_at: now, updated_at: now }
        end
        Calendar::BusyEvent.insert_all(rows) if rows.any?
        update!(synced_at: now, error: nil)
      end
    rescue Calendar::Fetch::Error => error
      update!(error: error.message)
    end
  end
end
