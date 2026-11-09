# The calendar's own settings for the install (one row: a person's workload limit, the Monday
# look-ahead, a public holiday calendar to follow) and its holidays (days off for everyone, added
# by hand or read from that calendar).
class CreateCalendarSettingsAndHolidays < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_settings do |t|
      t.integer :workload_limit, null: false, default: 5
      t.boolean :look_ahead, null: false, default: false
      t.date :look_ahead_sent_on
      t.string :holidays_url
      t.datetime :holidays_synced_at
      t.string :holidays_error
      t.timestamps
    end

    create_table :calendar_holidays do |t|
      t.date :date, null: false
      t.string :name, null: false
      t.string :source, null: false, default: "manual"
      t.timestamps
    end
    add_index :calendar_holidays, [ :date, :source ]
  end
end
