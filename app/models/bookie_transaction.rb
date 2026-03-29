class BookieTransaction < ActiveRecord::Base
  belongs_to :user
  belongs_to :bookie_match, foreign_key: :match_id, optional: true

  TYPES = %w[
    starting_balance
    weekly_bonus
    season_reset
    league_points
    monthly_reset
    bet_placed
    bet_won
    bet_lost
    bet_cancelled
  ].freeze

  validates :user_id, :transaction_type, :amount, presence: true
end
