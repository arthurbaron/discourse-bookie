class BookieLeagueEntry < ActiveRecord::Base
  belongs_to :user

  # ── Period helpers ────────────────────────────────────────────────────────

  PERIODS = [
    { months: [8, 9],   label: "Aug-Sep" },
    { months: [10, 11], label: "Oct-Nov" },
    { months: [12, 1],  label: "Dec-Jan" },
    { months: [2, 3],   label: "Feb-Mar" },
    { months: [4, 5],   label: "Apr-May" },
  ].freeze

  def self.period_for(date = Date.today)
    month = date.month
    # Dec-Jan spans two calendar years — year is the year of December
    year = (month == 1) ? date.year - 1 : date.year
    period = PERIODS.find { |p| p[:months].include?(month) }
    return nil unless period
    "#{period[:label].downcase.gsub(' ', '-')}-#{year}"  # e.g. "aug-sep-2026"
  end

  def self.period_label_for(period_key)
    # "aug-sep-2026" → "Aug-Sep 2026"
    parts = period_key.split("-")
    year  = parts.last
    label = parts[0...-1].map(&:capitalize).join("-")
    "#{label} #{year}"
  end

  def self.current_period_key
    period_for(Date.today)
  end

  # ── Finders ───────────────────────────────────────────────────────────────

  def self.for_user(user_id, period_key = nil)
    period_key ||= current_period_key
    find_or_create_by!(user_id: user_id, period_key: period_key)
  end

  scope :for_period, ->(period_key) {
    where(period_key: period_key).order(points: :desc)
  }

  # ── Points calculation ────────────────────────────────────────────────────

  # Called when a bet is settled (won or lost)
  def self.record_settled_bet!(user_id:, won:, odds:, match_id: nil)
    period_key = current_period_key
    return unless period_key  # outside season (e.g. June/July)

    entry = for_user(user_id, period_key)
    entry.with_lock do
      pts = 0

      # Activity bonus — for placing the bet (always)
      pts += 2
      entry.bets_placed += 1

      if won
        # Correct pick base
        pts += 10
        # Odds bonus: round((odds - 1) * 4)
        pts += [(odds.to_f - 1) * 4, 0].max.round
        entry.correct_picks  += 1
        entry.current_streak += 1
        entry.longest_streak  = [entry.longest_streak, entry.current_streak].max

        # Streak milestone bonuses
        streak = entry.current_streak
        pts += 8  if streak == 3
        pts += 18 if streak == 5
        pts += 35 if streak == 8
      else
        entry.current_streak = 0  # streak broken
      end

      entry.points += pts
      entry.save!

      # Log the points as a transaction for transparency
      BookieTransaction.create!(
        user_id:          user_id,
        transaction_type: "league_points",
        amount:           pts,
        description:      won ? "League pts: correct pick (#{pts} pts)" : "League pts: activity bonus (#{pts} pts)",
        match_id:         match_id
      )
    end
  end

  # ── Period close ──────────────────────────────────────────────────────────

  def self.close_period!(period_key)
    top = for_period(period_key).includes(:user).limit(3)
    top.each_with_index do |entry, i|
      BookiePeriodSnapshot.create!(
        period_key: period_key,
        user_id:    entry.user_id,
        rank:       i + 1,
        points:     entry.points
      )
    end
  end
end
