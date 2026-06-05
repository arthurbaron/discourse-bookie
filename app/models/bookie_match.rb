class BookieMatch < ActiveRecord::Base
  belongs_to :home_club, class_name: "BookieClub", optional: true
  belongs_to :away_club, class_name: "BookieClub", optional: true
  # :destroy (not :nullify) because bookie_bets.match_id is NOT NULL — nullify
  # would raise a constraint violation. destroy_match only deletes open matches
  # (settled ones are blocked) and refunds their pending bets first, so the
  # cascade only removes already-refunded bets.
  has_many :bookie_bets, foreign_key: :match_id, dependent: :destroy

  SPORTS = {
    "football" => { label: "Football", icon: "⚽", draw: true },
    "boxing"   => { label: "Boxing",   icon: "🥊", draw: false },
    "tennis"   => { label: "Tennis",   icon: "🎾", draw: false },
  }.freeze

  attribute :sport, :string, default: "football"

  before_validation :assign_canonical_clubs
  before_validation :clear_draw_odds_for_two_outcome_sports

  validates :title, :home_team, :away_team, :deadline, presence: true
  validates :odds_home, :odds_away,
            numericality: { greater_than: 1.0, less_than: 100.0 }
  validates :odds_draw,
            numericality: { greater_than: 1.0, less_than: 100.0 }, allow_nil: true
  validates :status, inclusion: { in: %w[open settled] }
  validates :result, inclusion: { in: %w[home draw away] }, allow_nil: true
  validates :sport, inclusion: { in: SPORTS.keys }
  validate :draw_odds_present_when_sport_has_draw

  # Betting still open (deadline not yet passed)
  scope :bettable,     -> { where(status: "open").where("deadline > ?", Time.now) }
  # All unsettled matches — including those past deadline awaiting admin settlement
  scope :unsettled,    -> { where(status: "open").order(:deadline) }
  scope :upcoming,     -> { bettable.order(:deadline) }
  scope :settled,      -> { where(status: "settled").order(updated_at: :desc) }

  def deadline_passed?
    deadline <= Time.now
  end

  def can_bet?
    status == "open" && !deadline_passed?
  end

  def odds_for(choice)
    case choice
    when "home" then odds_home.to_f
    when "draw" then odds_draw&.to_f
    when "away" then odds_away.to_f
    end
  end

  def home_canonical_name
    home_club&.name || home_team
  end

  def away_canonical_name
    away_club&.name || away_team
  end

  def sport_config
    SPORTS.fetch(sport, SPORTS["football"])
  end

  def has_draw?
    sport_config[:draw]
  end

  def sport_label
    sport_config[:label]
  end

  def sport_icon
    sport_config[:icon]
  end

  # Called by admin when entering the match result.
  # Pays out winning bets and updates all bet statuses.
  def settle!(result_choice)
    valid_results = has_draw? ? %w[home draw away] : %w[home away]
    return false unless valid_results.include?(result_choice)

    did_settle = false

    ActiveRecord::Base.transaction do
      lock!                          # row lock — serialises concurrent / double settles
      next if status == "settled"    # re-check under the lock (idempotent, no double payout)

      update!(result: result_choice, status: "settled")
      settled_user_ids = []

      bookie_bets.where(status: "pending").each do |bet|
        won = bet.choice == result_choice
        if won
          payout = (bet.amount * bet.odds).round
          bet.update!(status: "won", payout: payout)
          wallet = BookieWallet.find_or_create_for_user(bet.user_id)
          wallet.credit!(payout, "Won: #{title}", match_id: id, type: "bet_won")
        else
          bet.update!(status: "lost", payout: 0)
          BookieTransaction.create!(
            user_id:          bet.user_id,
            transaction_type: "bet_lost",
            amount:           0,
            description:      "Lost: #{title}",
            match_id:         id
          )
        end

        # Award League Table points
        BookieLeagueEntry.record_settled_bet!(
          user_id: bet.user_id,
          won:     won,
          odds:    bet.odds,
          match_id: id
        )

        settled_user_ids << bet.user_id
      end

      # ── Settle accumulator legs on this match, then re-evaluate their accas ──
      legs = BookieAccumulatorLeg.where(match_id: id, status: "pending").to_a
      legs.each do |leg|
        leg.update!(status: leg.choice == result_choice ? "won" : "lost")
      end
      legs.map(&:accumulator_id).uniq.each do |acc_id|
        acc = BookieAccumulator.find(acc_id)
        acc.recalculate_and_settle!
        settled_user_ids << acc.user_id
      end

      # One consolidated "Bets settled" notification per affected user
      BookieNotifier.notify_bets_settled!(user_ids: settled_user_ids)

      did_settle = true
    end

    did_settle
  end

  private

  def draw_odds_present_when_sport_has_draw
    return unless has_draw?

    errors.add(:odds_draw, "is required for this sport") if odds_draw.blank?
  end

  # 2-outcome sports (boxing/tennis) never have a draw, so blank out any draw
  # odds (e.g. the column default) before saving — regardless of schema.
  def clear_draw_odds_for_two_outcome_sports
    self.odds_draw = nil unless has_draw?
  end

  def assign_canonical_clubs
    return unless sport == "football"  # club aliases are football-specific
    return if home_team.blank? || away_team.blank?

    home_result = BookieClubResolver.find_or_create!(home_team)
    away_result = BookieClubResolver.find_or_create!(away_team)

    self.home_club = home_result.club if home_result.club
    self.away_club = away_result.club if away_result.club
    self.home_team = home_result.canonical_name if home_result.canonical_name.present?
    self.away_team = away_result.canonical_name if away_result.canonical_name.present?
  end
end
