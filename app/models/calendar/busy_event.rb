module Calendar
  # One busy stretch read from a person's own calendar (Calendar::BusyFeed): all day (out, for
  # clashes) or a meeting between two times. Its title is shown only to the person.
  class BusyEvent < ApplicationRecord
    self.table_name = "calendar_busy_events"

    belongs_to :user

    scope :overlapping, ->(range) { where(starts_on: ..range.last, ends_on: range.first..) }

    def covers?(date) = (starts_on..ends_on).cover?(date)
    def title_for(viewer) = viewer&.person == user ? title : "Busy"
    def time_text = all_day ? "All day" : "#{I18n.l(starts_at, format: "%-l:%M%P")}–#{I18n.l(ends_at, format: "%-l:%M%P")}"
  end
end
