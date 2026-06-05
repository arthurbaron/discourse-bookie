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

  def leg_count
    bookie_accumulator_legs.size
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
        BookieLeagueEntry.record_won_accumulator!(user_id: user_id)
      end
      # else: some legs still pending and none lost → leave pending (no-op)
    end
  end
end
