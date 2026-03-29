class BookieSeasonSnapshot < ActiveRecord::Base
  belongs_to :user

  # e.g. "2025-26" — based on the football season (Aug–May)
  def self.current_season_key
    today = Date.today
    if today.month >= 8
      "#{today.year}-#{(today.year + 1).to_s.last(2)}"
    else
      "#{today.year - 1}-#{today.year.to_s.last(2)}"
    end
  end

  scope :for_season, ->(key) { where(season_key: key).order(rank: :asc) }

  # Snapshot the current Richest Gooner top 3 and reset all wallets.
  # Called from AdminBookieController#end_season.
  def self.close_season!(season_key)
    transaction do
      raise "Season #{season_key} has already been closed." if where(season_key: season_key).exists?

      # Snapshot top 3 active wallets (only users who placed at least one bet)
      top = BookieWallet
        .joins("JOIN bookie_bets ON bookie_bets.user_id = bookie_wallets.user_id")
        .joins("JOIN users ON users.id = bookie_wallets.user_id")
        .where("users.active = true")
        .distinct
        .order(balance: :desc)
        .limit(3)
        .includes(:user)

      top.each_with_index do |wallet, i|
        create!(
          season_key: season_key,
          user_id:    wallet.user_id,
          rank:       i + 1,
          balance:    wallet.balance
        )
      end

      # Reset every wallet to starting balance in the same transaction, so
      # the season cannot end up half-closed if one update fails.
      starting = SiteSetting.bookie_starting_balance rescue 1000
      BookieWallet.find_each do |wallet|
        wallet.with_lock do
          diff = starting - wallet.balance
          next if diff == 0

          wallet.update!(balance: starting)
          BookieTransaction.create!(
            user_id:          wallet.user_id,
            transaction_type: "season_reset",
            amount:           diff,
            description:      "New season — balance reset to #{starting} coins"
          )
        end
      end
    end
  end
end
