# Monthly Money Sprint — ranks players by their net coin profit within a
# calendar month, instead of by total wallet balance (Richest Gooner).
#
# Only settled betting activity counts: single bets and accumulators, attributed
# to the month they settled in. Weekly bonuses, admin grants, season resets and
# refunds (cancelled bets / voided accas) are deliberately excluded, so the board
# reflects betting performance rather than handouts.
class BookieSprint
  def self.current_month_key(date = Date.today)
    date.strftime("%Y-%m")
  end

  def self.month_label_for(month_key)
    Date.strptime(month_key.to_s, "%Y-%m").strftime("%B %Y")
  rescue ArgumentError, TypeError
    month_key.to_s
  end

  # The month that just ended (used when closing a sprint).
  def self.closable_month_key(date = Date.today)
    (date.beginning_of_month - 1).strftime("%Y-%m")
  end

  def self.month_range(month_key)
    start_date = Date.strptime(month_key.to_s, "%Y-%m")
    start_time = start_date.beginning_of_month.in_time_zone.beginning_of_day
    end_time   = start_date.end_of_month.in_time_zone.end_of_day
    start_time..end_time
  end

  # => [{ user_id:, profit:, bets_count: }, ...] ranked best first
  def self.standings_for(month_key = current_month_key, limit: 50)
    range = month_range(month_key)
    totals = Hash.new { |hash, key| hash[key] = { profit: 0, bets_count: 0 } }

    single_bet_totals(range).each do |user_id, profit, count|
      totals[user_id][:profit] += profit.to_i
      totals[user_id][:bets_count] += count.to_i
    end

    accumulator_totals(range).each do |user_id, profit, count|
      totals[user_id][:profit] += profit.to_i
      totals[user_id][:bets_count] += count.to_i
    end

    totals
      .map { |user_id, data| { user_id: user_id }.merge(data) }
      # Tiebreaker: equal profit → fewer settled bets wins (efficiency)
      .sort_by { |row| [-row[:profit], row[:bets_count], row[:user_id]] }
      .first(limit)
  end

  def self.single_bet_totals(range)
    BookieBet
      .joins(:bookie_match)
      .where(status: %w[won lost])
      .where(bookie_matches: { status: "settled", updated_at: range })
      .group("bookie_bets.user_id")
      .pluck(
        Arel.sql("bookie_bets.user_id"),
        Arel.sql(
          "SUM(CASE WHEN bookie_bets.status = 'won' " \
          "THEN COALESCE(bookie_bets.payout, 0) - bookie_bets.amount " \
          "ELSE -bookie_bets.amount END)"
        ),
        Arel.sql("COUNT(*)")
      )
  end

  def self.accumulator_totals(range)
    BookieAccumulator
      .where(status: %w[won lost], settled_at: range)
      .group(:user_id)
      .pluck(
        Arel.sql("user_id"),
        Arel.sql(
          "SUM(CASE WHEN status = 'won' " \
          "THEN COALESCE(payout, 0) - amount " \
          "ELSE -amount END)"
        ),
        Arel.sql("COUNT(*)")
      )
  end

  # Snapshot the top 3 of a finished month so past winners stay visible.
  def self.close_month!(month_key)
    return if BookieSprintSnapshot.where(month_key: month_key).exists?

    standings_for(month_key, limit: 3).each_with_index do |row, index|
      BookieSprintSnapshot.create!(
        month_key: month_key,
        user_id:   row[:user_id],
        rank:      index + 1,
        profit:    row[:profit]
      )
    end
  end
end
