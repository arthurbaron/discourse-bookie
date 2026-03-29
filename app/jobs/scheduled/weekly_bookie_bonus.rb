module Jobs
  class WeeklyBookieBonus < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      bonus = SiteSetting.bookie_weekly_bonus rescue 100
      return if bonus <= 0

      # Idempotency: skip if any wallet already received the bonus this week
      week_start = Date.today.beginning_of_week.beginning_of_day
      week_end   = Date.today.end_of_week.end_of_day
      already_ran = BookieTransaction
        .where(transaction_type: "weekly_bonus")
        .where(created_at: week_start..week_end)
        .exists?
      return if already_ran

      BookieWallet.find_each do |wallet|
        wallet.credit!(
          bonus,
          "Weekly bonus — #{bonus} free coins!",
          type: "weekly_bonus"
        )
      rescue => e
        Rails.logger.error("[discourse-bookie] WeeklyBookieBonus failed for user #{wallet.user_id}: #{e.message}")
      end
    end
  end
end
