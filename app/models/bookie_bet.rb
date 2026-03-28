class BookieBet < ActiveRecord::Base
  belongs_to :user
  belongs_to :bookie_match, foreign_key: :match_id

  validates :user_id, :match_id, :choice, :amount, :odds, presence: true
  validates :choice, inclusion: { in: %w[home draw away] }
  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending won lost] }
  validates :user_id, uniqueness: { scope: :match_id,
                                    message: "has already placed a bet on this match" }

  scope :pending, -> { where(status: "pending") }
  scope :won,     -> { where(status: "won") }
  scope :lost,    -> { where(status: "lost") }

  def potential_payout
    (amount * odds).round
  end
end
