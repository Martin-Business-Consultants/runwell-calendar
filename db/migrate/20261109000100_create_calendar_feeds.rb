# A person's private calendar feed (.ics), subscribed to from Google Calendar, Outlook or Apple's:
# one per person. Only its token's digest is kept, so the link shows once, when it's made; it's
# reset or turned off from the Calendar's Subscribe page.
class CreateCalendarFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_feeds do |t|
      t.integer :user_id, null: false
      t.string :token_digest, null: false
      t.datetime :last_fetched_at
      t.timestamps
    end
    add_index :calendar_feeds, :user_id, unique: true
    add_index :calendar_feeds, :token_digest, unique: true
  end
end
