# Runs daily via Discourse's scheduler.
# On the 1st of each month it snapshots the top 3 of the month that just ended,
# so previous Money Sprint winners stay visible in Standings.
module Jobs
  class CloseBookieSprint < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      today = Date.today
      return unless today.day == 1

      closing_key = BookieSprint.closable_month_key(today)
      return if closing_key.blank?

      # Idempotent — skip if this month was already snapshotted
      return if BookieSprintSnapshot.where(month_key: closing_key).exists?

      Rails.logger.info("[CloseBookieSprint] Closing sprint #{closing_key}")
      BookieSprint.close_month!(closing_key)
      Rails.logger.info("[CloseBookieSprint] Done — top 3 snapshotted for #{closing_key}")
    end
  end
end
