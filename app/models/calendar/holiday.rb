module Calendar
  # A day off for everyone (a public holiday, the office closed): added by hand in the calendar's
  # settings, or read from the public holiday calendar it follows. On a holiday everyone counts as
  # out, so a task or launch due then is a clash.
  class Holiday < ApplicationRecord
    self.table_name = "calendar_holidays"
    SOURCES = %w[manual feed].freeze

    validates :date, :name, presence: true
    validates :source, inclusion: { in: SOURCES }
    normalizes :name, with: ->(name) { name.to_s.squish.truncate(80) }

    scope :between, ->(range) { where(date: range) }
    scope :ordered, -> { order(:date, :name) }
    scope :upcoming, -> { where(date: Date.current..) }

    def manual? = source == "manual"
  end
end
