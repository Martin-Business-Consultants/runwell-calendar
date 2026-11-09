# A person's own calendar (Google, Outlook, Apple), connected by its private link, read for when
# they're busy: an all-day busy event counts as out, a meeting as busy for part of the day. The
# link is encrypted; what's read is replaced at each sync.
class CreateCalendarBusy < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_busy_feeds do |t|
      t.integer :user_id, null: false
      t.text :url, null: false
      t.datetime :synced_at
      t.string :error
      t.timestamps
    end
    add_index :calendar_busy_feeds, :user_id, unique: true

    create_table :calendar_busy_events do |t|
      t.integer :user_id, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :all_day, null: false, default: false
      t.string :title
      t.timestamps
    end
    add_index :calendar_busy_events, [ :user_id, :starts_on, :ends_on ]
  end
end
