class BookieMonthlySnapshot < ActiveRecord::Base
  belongs_to :user

  validates :user_id, :month, :year, :final_balance, presence: true

  scope :for_month, ->(month, year) {
    where(month: month, year: year).order(:rank)
  }

  # Takes a snapshot of every wallet and assigns ranks.
  # Called on the 1st of each month before the reset.
  def self.snapshot_and_reset!
    now      = Date.today
    snap_m   = now.prev_month.month
    snap_y   = now.prev_month.year

    wallets = BookieWallet.order(balance: :desc)
    wallets.each_with_index do |wallet, idx|
      find_or_create_by!(user_id: wallet.user_id, month: snap_m, year: snap_y) do |s|
        s.final_balance = wallet.balance
        s.rank          = idx + 1
      end
    end

    # Reset all wallets to starting balance
    starting = SiteSetting.bookie_starting_balance
    wallets.each do |wallet|
      old_balance = wallet.balance
      wallet.update!(balance: starting)
      BookieTransaction.create!(
        user_id:          wallet.user_id,
        transaction_type: "monthly_reset",
        amount:           starting - old_balance,
        description:      "Monthly reset — new season starts!"
      )
    end
  end
end
