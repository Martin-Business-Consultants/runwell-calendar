module Calendar
  # A person's week ahead, sent on Monday morning when the calendar's settings turn it on: their
  # open tasks due this week (and how many are overdue), who's out and the holidays, and any clash
  # (their task due on a day they're out). Nothing is sent to someone with nothing in their week.
  class LookAhead
    attr_reader :person, :week

    def self.send_this_week(force: false)
      setting = Calendar::Setting.current
      return unless force || (setting.look_ahead? && Date.current.monday? && setting.look_ahead_sent_on != Date.current)

      setting.update!(look_ahead_sent_on: Date.current)
      User.people.active.find_each do |person|
        Calendar::LookAheadMailer.with(person: person).week.deliver_later if new(person).worth_sending?
      end
    end

    def initialize(person, week: Date.current..(Date.current + 6))
      @person, @week = person, week
    end

    def tasks = @tasks ||= Task.open.assigned_to(person).where(due_on: week).includes(:work, :client).order(:due_on, :title).to_a
    def overdue = @overdue ||= Task.open.assigned_to(person).where(due_on: ...week.first).count
    def out = @out ||= Calendar::TimeOff.overlapping(week).includes(:user).ordered.to_a
    def holidays = @holidays ||= Calendar::Holiday.between(week).ordered.to_a

    # Their tasks due on a day they're out (time off or a holiday).
    def clashes
      @clashes ||= tasks.select do |task|
        holidays.any? { it.date == task.due_on } || out.any? { it.user_id == person.id && it.covers?(task.due_on) }
      end
    end

    def worth_sending? = tasks.any? || overdue.positive? || out.any? || holidays.any?
  end
end
