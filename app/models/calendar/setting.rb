module Calendar
  # The calendar's settings for the install (Settings > Plugins > Calendar), one row: how many open
  # tasks due in a day is too many for one person (workload_limit), whether everyone gets a Monday
  # look-ahead, and a public holiday calendar to follow (its link, read nightly).
  class Setting < ApplicationRecord
    self.table_name = "calendar_settings"

    validates :workload_limit, numericality: { only_integer: true, in: 1..50 }
    validates :holidays_url, format: { with: %r{\A(https|webcal)://\S+\z}i, message: "should start with https://" }, allow_blank: true
    normalizes :holidays_url, with: ->(url) { url.to_s.strip.presence }

    def self.current = first || create!

    # Reads the holiday calendar again, replacing the holidays it gave before. Records the error,
    # in words, when it can't.
    def sync_holidays!
      if holidays_url.blank?
        Calendar::Holiday.where(source: "feed").delete_all
        return update!(holidays_synced_at: nil, holidays_error: nil)
      end

      window = Date.current.beginning_of_year..(Date.current + 2.years)
      events = Calendar::IcsReader.new(Calendar::Fetch.get(holidays_url), window: window).events.select(&:all_day)
      transaction do
        Calendar::Holiday.where(source: "feed").delete_all
        rows = events.flat_map { |event| (event.starts_on..event.ends_on).map { { date: it, name: event.title.truncate(80), source: "feed" } } }
        Calendar::Holiday.insert_all(rows.map { it.merge(created_at: Time.current, updated_at: Time.current) }) if rows.any?
        update!(holidays_synced_at: Time.current, holidays_error: nil)
      end
    rescue Calendar::Fetch::Error => error
      update!(holidays_error: error.message)
    end
  end
end
