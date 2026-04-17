class BookieMatch < ActiveRecord::Base
  belongs_to :home_club, class_name: "BookieClub", optional: true
  belongs_to :away_club, class_name: "BookieClub", optional: true
  has_many :bookie_bets, foreign_key: :match_id, dependent: :nullify

  before_validation :assign_canonical_clubs

  validates :title, :home_team, :away_team, :deadline, presence: true
  validates :odds_home, :odds_draw, :odds_away,
            numericality: { greater_than: 1.0, less_than: 100.0 }
  validates :status, inclusion: { in: %w[open settled] }
  validates :result, inclusion: { in: %w[home draw away] }, allow_nil: true

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
    when "draw" then odds_draw.to_f
    when "away" then odds_away.to_f
    end
  end

  def home_canonical_name
    home_club&.name || home_team
  end

  def away_canonical_name
    away_club&.name || away_team
  end

  # Called by admin when entering the match result.
  # Pays out winning bets and updates all bet statuses.
  def settle!(result_choice)
    return false unless %w[home draw away].include?(result_choice)
    return false if status == "settled"

    ActiveRecord::Base.transaction do
      update!(result: result_choice, status: "settled")
      currency_name = SiteSetting.bookie_currency_name rescue "coins"
      currency_name = "coins" if currency_name == "Coins"

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

        BookieNotifier.notify_match_settled!(
          match: self,
          bet: bet,
          won: won,
          currency_name: currency_name
        )
      end
    end

    true
  end

  private

  def assign_canonical_clubs
    return if home_team.blank? || away_team.blank?

    home_result = BookieClubResolver.find_or_create!(home_team)
    away_result = BookieClubResolver.find_or_create!(away_team)

    self.home_club = home_result.club if home_result.club
    self.away_club = away_result.club if away_result.club
    self.home_team = home_result.canonical_name if home_result.canonical_name.present?
    self.away_team = away_result.canonical_name if away_result.canonical_name.present?
  end
end
