module Calendar
  # A person's private calendar feed: a link Google Calendar, Outlook or Apple's Calendar
  # subscribes to (.ics), showing their tasks with a due date, everyone's time off and every date
  # they may see. Only the token's digest is stored, so the link shows once, when it's made;
  # resetting it makes a new one and the old stops working. Made and reset only by its person, in
  # the browser.
  class Feed < ApplicationRecord
    self.table_name = "calendar_feeds"

    belongs_to :user

    attr_reader :token

    def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

    # A new link for the person, replacing any they had. The token is readable once, on the record.
    def self.issue!(user)
      token = "cal_#{SecureRandom.base58(32)}"
      feed = find_or_initialize_by(user: user)
      feed.update!(token_digest: digest(token), last_fetched_at: nil)
      feed.tap { it.instance_variable_set(:@token, token) }
    end

    # The feed for a token, while its person can still use Runwell.
    def self.find_by_token(token)
      return if token.blank?

      find_by(token_digest: digest(token))&.then { it if it.user.active? && !it.user.client? }
    end

    # Written at most once an hour: calendars poll often.
    def fetched!
      update_column(:last_fetched_at, Time.current) if last_fetched_at.nil? || last_fetched_at < 1.hour.ago
    end
  end
end
