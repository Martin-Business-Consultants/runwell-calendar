module Calendar
  # A task's place among the others due the same day (dragged up or down a day, or dropped among
  # them). The day is the task's own due date; this holds only the order, so a task with none sorts
  # after those that have one. Kept in the plugin's table, never on the task.
  class Placement < ApplicationRecord
    self.table_name = "calendar_placements"

    belongs_to :task

    # task_id → position for these tasks, for sorting a range of days in one query.
    def self.positions_for(task_ids) = where(task_id: task_ids).pluck(:task_id, :position).to_h

    # Puts the task on its due day just before `before` (another task's id that day), or at the end,
    # numbering that day's tasks again in their new order.
    def self.place!(task, before: nil)
      return unless task.due_on

      others = Task.where(due_on: task.due_on).where.not(id: task.id).pluck(:id, :title)
      positions = positions_for(others.map(&:first))
      order = others.sort_by { |id, title| [ positions[id] || Float::INFINITY, title.to_s.downcase ] }.map(&:first)
      at = before.present? && order.index(before.to_i)
      order.insert(at || order.size, task.id)

      now = Time.current
      transaction do
        upsert_all(order.each_with_index.map { |id, position| { task_id: id, position: position, created_at: now, updated_at: now } },
          unique_by: :task_id, update_only: %i[position updated_at])
      end
    end
  end
end
