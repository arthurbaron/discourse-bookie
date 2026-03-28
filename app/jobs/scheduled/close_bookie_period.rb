# Runs daily via Discourse's scheduler.
# On the first day of Oct / Dec / Feb / Apr / Jun it snapshots the top 3
# of the period that just ended, so previous winners appear in Standings.
module Jobs
  class CloseBokiePeriod < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      today = Date.today

      # Only act on the first day of months that follow a closed period:
      #   Oct 1  → closes Aug-Sep
      #   Dec 1  → closes Oct-Nov
      #   Feb 1  → closes Dec-Jan
      #   Apr 1  → closes Feb-Mar
      #   Jun 1  → closes Apr-May
      return unless today.day == 1 && [2, 4, 6, 10, 12].include?(today.month)

      # The period that just ended = yesterday's period
      closing_key = BookieLeagueEntry.period_for(today - 1)
      return unless closing_key

      # Idempotent — skip if already snapshotted (e.g. job re-runs)
      return if BookiePeriodSnapshot.where(period_key: closing_key).exists?

      Rails.logger.info("[CloseBokiePeriod] Closing period #{closing_key}")
      BookieLeagueEntry.close_period!(closing_key)
      Rails.logger.info("[CloseBokiePeriod] Done — top 3 snapshotted for #{closing_key}")
    end
  end
end
