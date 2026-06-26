class BookieAccumulator < ActiveRecord::Base
  belongs_to :user
  has_many :bookie_accumulator_legs, foreign_key: :accumulator_id, dependent: :destroy

  MIN_LEGS = 2

  validates :user_id, :amount, :combined_odds, :potential_payout, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending won lost cancelled void] }

  scope :pending, -> { where(status: "pending") }

  def self.max_legs
    SiteSetting.bookie_acca_max_legs rescue 8
  end

  def self.max_open
    SiteSetting.bookie_max_open_accas rescue 3
  end

  # Minimum combined odds for a won accumulator to earn League Table points,
  # so trivial favourite-doubles don't hand out free points.
  def self.league_min_odds
    (SiteSetting.bookie_acca_league_min_odds rescue 4.0).to_f
  end

  def leg_count
    bookie_accumulator_legs.size
  end

  def all_football?
    bookie_accumulator_legs.includes(:bookie_match).all? do |leg|
      leg.bookie_match&.sport == "football"
    end
  end

  # Re-evaluate this accumulator after one of its legs' matches has settled.
  # Race-safe + idempotent: a row lock + the pending re-check guarantee a
  # single payout even if settlement runs concurrently or a match is settled
  # twice. Called from BookieMatch#settle! (wired in phase 2).
  def recalculate_and_settle!
    with_lock do
      return unless status == "pending"

      statuses = bookie_accumulator_legs.pluck(:status)

      if statuses.include?("lost")
        # One leg lost → the whole accumulator is lost, even if other legs
        # are still pending (standard behaviour, clearer for the user).
        update!(status: "lost", payout: 0, settled_at: Time.zone.now)
      elsif statuses.all? { |s| s == "won" }
        pay = (amount * combined_odds).round
        update!(status: "won", payout: pay, settled_at: Time.zone.now)
        BookieWallet
          .find_or_create_for_user(user_id)
          .credit!(pay, "Accumulator won (#{leg_count} legs)", type: "acca_won")

        # League bonus only for higher-odds, all-football accas — the League
        # Table is football-only. Mixed-sport accas pay out in coins only.
        if all_football? && combined_odds.to_f >= self.class.league_min_odds
          BookieLeagueEntry.record_won_accumulator!(user_id: user_id)
        end
      end
      # else: some legs still pending and none lost → leave pending (no-op)
    end
  end
end
