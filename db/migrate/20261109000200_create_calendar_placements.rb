# A task's place among the others due the same day, as someone arranged them on the calendar. Its
# day is the task's own due date; this keeps only the order within it.
class CreateCalendarPlacements < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_placements do |t|
      t.integer :task_id, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :calendar_placements, :task_id, unique: true
  end
end
