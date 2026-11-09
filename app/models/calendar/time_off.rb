module Calendar
  # A person out: whole days from starts_on to ends_on, or half of a single day. Anyone adds their
  # own; whoever may manage time off (owners and managers, `manage_time_off`) adds and removes
  # anyone's. There's no approval: it says who's away, not who allowed it. The note is private to
  # the person and those who manage time off, so a reason never lands on everyone's calendar.
  class TimeOff < ApplicationRecord
    self.table_name = "calendar_time_offs"

    belongs_to :user
    belongs_to :created_by, class_name: "User", optional: true

    validates :starts_on, :ends_on, presence: true
    validates :note, length: { maximum: 200 }
    validate :ends_after_it_starts
    validate :half_day_is_one_day
    validate :for_someone_on_staff

    before_validation { self.ends_on ||= starts_on }
    normalizes :note, with: ->(note) { note.to_s.strip.presence }

    scope :ordered, -> { order(:starts_on, :ends_on) }
    # Any day of it inside the range.
    scope :overlapping, ->(range) { where(starts_on: ..range.last, ends_on: range.first..) }
    scope :upcoming, -> { where(ends_on: Date.current..) }

    def days = starts_on..ends_on
    def covers?(date) = days.cover?(date)

    # "Out" or "Out (half day)", as the calendar says it.
    def label = half_day? ? "Out (half day)" : "Out"

    # "Nov 20" or "Nov 20 – 24".
    def span_text
      return I18n.l(starts_on, format: "%b %-d") if starts_on == ends_on

      [ I18n.l(starts_on, format: "%b %-d"), I18n.l(ends_on, format: starts_on.month == ends_on.month ? "%-d" : "%b %-d") ].join(" – ")
    end

    def manageable_by?(person) = person.present? && (person.person == user || person.can?(:manage_time_off))
    def note_visible_to?(person) = manageable_by?(person)

    private
      def ends_after_it_starts
        errors.add(:ends_on, "can’t be before it starts") if starts_on && ends_on && ends_on < starts_on
      end

      def half_day_is_one_day
        errors.add(:half_day, "is for a single day") if half_day? && starts_on != ends_on
      end

      def for_someone_on_staff
        errors.add(:user, "must be someone on the team") if user && (user.client? || user.agent?)
      end
  end
end
