module Jobs
  class MonthlyBookieReset < ::Jobs::Scheduled
    # Runs at 00:05 on the 1st of every month
    every 1.month

    def execute(args)
      return unless SiteSetting.bookie_enabled

      # Only run on the 1st of the month
      return unless Date.today.day == 1

      BookieMonthlySnapshot.snapshot_and_reset!

      Rails.logger.info("[discourse-bookie] Monthly reset completed at #{Time.now}")
    rescue => e
      Rails.logger.error("[discourse-bookie] MonthlyBookieReset failed: #{e.message}")
    end
  end
end
