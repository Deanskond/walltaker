class Link < ApplicationRecord
  belongs_to :user
  has_many :past_links
  enum response_type: %i[horny came disgust]
  validates :expires, presence: true, unless: :never_expires?
  validates :theme, format: { without: /\s+/i, message: 'must be only 1 tag.' }
  visitable :ahoy_visit

  after_update_commit do
    if blacklist_previously_changed? || terms_previously_changed? || theme_previously_changed? || response_text_previously_changed? || last_ping_user_agent_previously_changed? || expires_previously_changed? || never_expires_previously_changed? || friends_only_previously_changed? || post_url_previously_changed?
      broadcast_update
    end
  end
end
