class BookieWallet < ActiveRecord::Base
  belongs_to :user

  STARTING_BALANCE = -> { SiteSetting.bookie_starting_balance rescue 1000 }
  WEEKLY_BONUS     = -> { SiteSetting.bookie_weekly_bonus rescue 100 }

  def self.find_or_create_for_user(user_id)
    find_or_create_by!(user_id: user_id) do |w|
      w.balance = STARTING_BALANCE.call
      BookieTransaction.create!(
        user_id:          user_id,
        transaction_type: "starting_balance",
        amount:           STARTING_BALANCE.call,
        description:      "Welcome! Starting balance"
      )
    end
  end

  # Remove coins (e.g. placing a bet)
  def debit!(amount, description, match_id: nil)
    raise ArgumentError, "Amount must be positive" if amount.to_i <= 0

    with_lock do
      reload
      raise "Insufficient balance" if balance < amount

      update!(balance: balance - amount)
      BookieTransaction.create!(
        user_id:          user_id,
        transaction_type: "bet_placed",
        amount:           -amount,
        description:      description,
        match_id:         match_id
      )
    end
  end

  # Add coins (e.g. winning a bet, weekly bonus)
  def credit!(amount, description, match_id: nil, type: "bet_won")
    with_lock do
      update!(balance: balance + amount)
      BookieTransaction.create!(
        user_id:          user_id,
        transaction_type: type,
        amount:           amount,
        description:      description,
        match_id:         match_id
      )
    end
  end
end
