class BookieAchievements
  DEFINITIONS = [
    {
      key: "first_win",
      title: "First Win",
      description: "Win your first Bookie bet.",
      image: "first-win.png"
    },
    {
      key: "hot_hand",
      title: "Hot Hand",
      description: "Land 3 correct picks in a row.",
      image: "hot-hand.png"
    },
    {
      key: "on_fire",
      title: "On Fire",
      description: "Land 5 correct picks in a row.",
      image: "on-fire.png"
    },
    {
      key: "club_specialist",
      title: "Club Specialist",
      description: "Earn 1,000+ coins with one team.",
      image: "club-specialist.png"
    },
    {
      key: "underdog_whisperer",
      title: "Underdog Whisperer",
      description: "Win a bet with odds above 4.0.",
      image: "underdog-whisperer.png"
    },
    {
      key: "draw_merchant",
      title: "Draw Merchant",
      description: "Correctly predict 2+ draws.",
      image: "draw-merchant.png"
    },
    {
      key: "big_payout",
      title: "Big Payout",
      description: "Win a single payout of 1,000+ coins.",
      image: "big-payout.png"
    },
    {
      key: "loyal_backer",
      title: "Loyal Backer",
      description: "Place 10 bets on the same team.",
      image: "loyal-backer.png"
    },
    {
      key: "period_winner",
      title: "Period Winner",
      description: "Finish #1 in a League Table period.",
      image: "period-winner.png"
    },
    {
      key: "richest_gooner_top3",
      title: "Richest Gooner Top 3",
      description: "Finish a season in the Richest Gooner top 3.",
      image: "richest-gooner-top3.png"
    }
  ].freeze

  DEFAULT_STARTED_AT = "2026-06-01T00:00:00Z".freeze

  def self.payload_for(user_id)
    earned_keys = earned_keys_for(user_id)

    DEFINITIONS.map do |achievement|
      {
        key: achievement[:key],
        title: achievement[:title],
        description: achievement[:description],
        image_url: image_url(achievement[:image]),
        earned: earned_keys.key?(achievement[:key])
      }
    end
  end

  def self.earned_for(user_id)
    earned_keys = earned_keys_for(user_id)

    DEFINITIONS
      .select { |achievement| earned_keys.key?(achievement[:key]) }
      .map do |achievement|
        {
          key: achievement[:key],
          title: achievement[:title],
          description: achievement[:description]
        }
      end
  end

  def self.started_at
    value = SiteSetting.bookie_achievements_started_at rescue nil
    Time.zone.parse(value.to_s).presence || Time.zone.parse(DEFAULT_STARTED_AT)
  rescue ArgumentError, TypeError
    Time.zone.parse(DEFAULT_STARTED_AT)
  end

  def self.image_url(filename)
    "#{Discourse.base_path.presence}/plugins/discourse-bookie/images/achievements/#{filename}"
  end

  def self.earned_keys_for(user_id)
    return {} if user_id.blank?

    started_at = self.started_at
    state = achievement_state_for(user_id, started_at)
    earned = {}

    earned["first_win"] = true if state[:wins].positive?
    earned["hot_hand"] = true if state[:best_streak] >= 3
    earned["on_fire"] = true if state[:best_streak] >= 5
    earned["underdog_whisperer"] = true if state[:won_underdog]
    earned["draw_merchant"] = true if state[:winning_draws] >= 2
    earned["big_payout"] = true if state[:biggest_payout] >= 1000
    earned["period_winner"] = true if BookiePeriodSnapshot
      .where(user_id: user_id, rank: 1)
      .where("created_at >= ?", started_at)
      .exists?
    earned["richest_gooner_top3"] = true if BookieSeasonSnapshot
      .where(user_id: user_id, rank: 1..3)
      .where("created_at >= ?", started_at)
      .exists?

    _best_team_name, best_team_profit =
      state[:team_profit].max_by { |team, profit| [profit, team] }
    earned["club_specialist"] = true if best_team_profit.to_i >= 1000

    _loyal_team, loyal_count =
      loyal_backer_counts_for(user_id, started_at)
        .max_by { |team, count| [count, team] }
    earned["loyal_backer"] = true if loyal_count.to_i >= 10

    earned
  end

  def self.achievement_state_for(user_id, started_at)
    state = {
      wins: 0,
      current_streak: 0,
      best_streak: 0,
      team_profit: Hash.new(0),
      winning_draws: 0,
      won_underdog: false,
      biggest_payout: 0
    }

    BookieBet
      .includes(bookie_match: %i[home_club away_club])
      .joins(:bookie_match)
      .where(user_id: user_id, status: %w[won lost])
      .where(bookie_matches: { status: "settled" })
      .where("bookie_matches.updated_at >= ?", started_at)
      .order("bookie_matches.updated_at ASC, bookie_bets.id ASC")
      .each do |bet|
        match = bet.bookie_match
        won = bet.status == "won"

        if won
          state[:wins] += 1
          state[:current_streak] += 1
          state[:best_streak] = [
            state[:best_streak],
            state[:current_streak]
          ].max
          state[:winning_draws] += 1 if bet.choice == "draw"
          state[:won_underdog] ||= bet.odds.to_f > 4.0
          state[:biggest_payout] = [
            state[:biggest_payout],
            bet.payout.to_i
          ].max
        else
          state[:current_streak] = 0
        end

        selected_team =
          case bet.choice
          when "home" then match&.home_canonical_name
          when "away" then match&.away_canonical_name
        end

        if selected_team.present?
          net_coin_delta =
            won ? (bet.payout.to_i - bet.amount.to_i) : -bet.amount.to_i
          state[:team_profit][selected_team] += net_coin_delta
        end
      end

    state
  end

  def self.loyal_backer_counts_for(user_id, started_at)
    counts = Hash.new(0)

    BookieBet
      .includes(bookie_match: %i[home_club away_club])
      .where(user_id: user_id, choice: %w[home away])
      .where("created_at >= ?", started_at)
      .find_each do |bet|
        match = bet.bookie_match
        next unless match

        team =
          case bet.choice
          when "home" then match.home_canonical_name
          when "away" then match.away_canonical_name
          end

        counts[team] += 1 if team.present?
      end

    counts
  end
end
