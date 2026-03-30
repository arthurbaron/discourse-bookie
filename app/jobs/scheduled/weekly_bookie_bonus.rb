module Jobs
  class WeeklyBookieBonus < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      bonus = SiteSetting.bookie_weekly_bonus rescue 100
      return if bonus <= 0
      return unless Date.today.monday?

      week_start = Date.today.beginning_of_week.beginning_of_day
      week_end   = Date.today.end_of_week.end_of_day

      BookieWallet.find_each do |wallet|
        wallet.with_lock do
          already_paid = BookieTransaction
            .where(user_id: wallet.user_id, transaction_type: "weekly_bonus")
            .where(created_at: week_start..week_end)
            .exists?
          next if already_paid

          wallet.update!(balance: wallet.balance + bonus)
          BookieTransaction.create!(
            user_id:          wallet.user_id,
            transaction_type: "weekly_bonus",
            amount:           bonus,
            description:      "Weekly bonus — #{bonus} free coins!"
          )
        end
      rescue => e
        Rails.logger.error("[discourse-bookie] WeeklyBookieBonus failed for user #{wallet.user_id}: #{e.message}")
      end
    end
  end
end
