# Who's out, and when: a person's days away (whole days, or half of one), with an optional note
# that only they and the people who manage time off read.
class CreateCalendarTimeOffs < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_time_offs do |t|
      t.integer :user_id, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.boolean :half_day, null: false, default: false
      t.string :note
      t.integer :created_by_id
      t.timestamps
    end
    add_index :calendar_time_offs, [ :starts_on, :ends_on ]
    add_index :calendar_time_offs, :user_id
  end
end
