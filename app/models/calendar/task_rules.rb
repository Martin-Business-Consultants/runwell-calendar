module Calendar
  # What the calendar may do with a core task, in one place, so every view, drop and tool agrees:
  # an open task moves (onto a day, within one, off the calendar); a done one keeps the date it was
  # done by. Overdue is an open task due before today.
  module TaskRules
    module_function

    def movable?(task) = task.status != "done"
    def overdue?(task) = movable?(task) && task.due_on.present? && task.due_on < Date.current
  end
end
