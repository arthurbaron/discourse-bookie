module Jobs
  class WeeklyBookieBonus < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      return unless SiteSetting.bookie_enabled
      return if SiteSetting.bookie_weekly_bonus <= 0

      bonus = SiteSetting.bookie_weekly_bonus

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
