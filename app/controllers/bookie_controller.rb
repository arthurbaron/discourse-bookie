class BookieController < ApplicationController
  requires_login

  before_action :ensure_bookie_enabled

  # GET /bookie/matches
  def matches
    open_matches = BookieMatch.unsettled.to_a
    match_ids    = open_matches.map(&:id)

    user_bets = BookieBet
      .where(user_id: current_user.id, match_id: match_ids)
      .index_by(&:match_id)

    wallet = BookieWallet.find_or_create_for_user(current_user.id)

    # Also include recently settled matches (last 10)
    settled = BookieMatch.settled.limit(10).to_a
    settled_ids = settled.map(&:id)
    settled_bets = BookieBet
      .where(user_id: current_user.id, match_id: settled_ids)
      .index_by(&:match_id)
    settled_scores = settled_match_scores_for(current_user.id, settled_ids)

    render json: {
      matches:         open_matches.map { |m| serialize_match(m, user_bets[m.id]) },
      settled_matches: settled.map { |m| serialize_match(m, settled_bets[m.id], settled_scores[m.id]) },
      stats:           results_stats_for(current_user.id),
      balance:         wallet.balance,
      currency:        bookie_currency
    }
  end

  # GET /bookie/wallet
  def wallet
    wallet       = BookieWallet.find_or_create_for_user(current_user.id)
    transactions = BookieTransaction
      .where(user_id: current_user.id)
      .order(created_at: :desc)
      .limit(50)

    render json: {
      balance:               wallet.balance,
      currency:              bookie_currency,
      transactions:          transactions.map { |t| serialize_transaction(t) },
      notifications_enabled: bookie_notifications_enabled?(current_user)
    }
  end

  # PUT /bookie/notifications
  def update_notifications
    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
    enabled = true if enabled.nil?
    current_user.upsert_custom_fields(
      "bookie_notifications_enabled" => enabled.to_s
    )

    render json: { notifications_enabled: enabled }
  end

  # GET /bookie/leaderboard
  def leaderboard
    # ── Richest Gooner (season-long coin balance) ──────────────────────────
    richest = BookieWallet
      .joins("JOIN users ON users.id = bookie_wallets.user_id")
      .joins("JOIN bookie_bets ON bookie_bets.user_id = bookie_wallets.user_id")
      .where("users.active = true AND (users.silenced_till IS NULL OR users.silenced_till < ?)", Time.now)
      .distinct
      .order(balance: :desc)
      .limit(50)
      .includes(:user)

    # ── League Table (current period points) ───────────────────────────────
    current_period = BookieLeagueEntry.current_period_key
    league_current = BookieLeagueEntry
      .for_period(current_period)
      .joins("JOIN users ON users.id = bookie_league_entries.user_id")
      .where("users.active = true")
      .includes(:user)
      .limit(50)

    # All period snapshots (excluding current period), grouped and sorted newest first
    all_snapshots = BookiePeriodSnapshot
      .includes(:user)
      .where.not(period_key: current_period)
      .order(period_key: :desc, rank: :asc)

    period_history = all_snapshots
      .group_by(&:period_key)
      .map do |key, entries|
        {
          period_key: key,
          label:      BookieLeagueEntry.period_label_for(key),
          top3:       entries.first(3).map do |s|
            { rank: s.rank, username: s.user.username, points: s.points,
              avatar_template: s.user.avatar_template }
          end
        }
      end
      .sort_by { |p| BookieLeagueEntry.period_sort_key(p[:period_key]) }
      .reverse

    render json: {
      # Richest Gooner
      richest_gooner: richest.map.with_index(1) do |w, i|
        { rank: i, username: w.user.username, balance: w.balance,
          avatar_template: w.user.avatar_template }
      end,

      # League Table – current period
      league_table: league_current.map.with_index(1) do |e, i|
        { rank: i, username: e.user.username, points: e.points,
          correct_picks: e.correct_picks, bets_placed: e.bets_placed,
          current_streak: e.current_streak, longest_streak: e.longest_streak,
          avatar_template: e.user.avatar_template }
      end,

      # Meta
      current_period_key:   current_period,
      current_period_label: BookieLeagueEntry.period_label_for(current_period.to_s),

      # History: all past periods with their top 3 (newest first)
      period_history: period_history,

      currency: bookie_currency
    }
  end

  # POST /bookie/bets
  def place_bet
    match  = BookieMatch.find(params[:match_id])
    choice = params[:choice].to_s
    amount = params[:amount].to_i

    return render_error("Betting is closed for this match.") unless match.can_bet?
    valid_choices = match.has_draw? ? %w[home draw away] : %w[home away]
    return render_error("Invalid choice.") unless valid_choices.include?(choice)
    return render_error("Minimum bet is #{bookie_min_bet} coins.") if amount < bookie_min_bet

    wallet = BookieWallet.find_or_create_for_user(current_user.id)
    return render_error("Insufficient balance.") if wallet.balance < amount

    if BookieBet.exists?(user_id: current_user.id, match_id: match.id)
      return render_error("You already placed a bet on this match.")
    end

    odds = match.odds_for(choice)

    ActiveRecord::Base.transaction do
      bet = BookieBet.create!(
        user_id:  current_user.id,
        match_id: match.id,
        choice:   choice,
        amount:   amount,
        odds:     odds,
        status:   "pending"
      )

      wallet.debit!(amount, "Bet on: #{match.title}", match_id: match.id)

      render json: {
        bet:         serialize_bet(bet),
        new_balance: wallet.reload.balance
      }
    end
  rescue ActiveRecord::RecordNotUnique
    render_error("You already placed a bet on this match.")
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  rescue => e
    log_internal_error("place_bet", e)
    render_error("Could not place your bet right now.", 500)
  end

  # DELETE /bookie/bets/:id
  def cancel_bet
    bet = BookieBet.find(params[:id])

    return render_error("Not authorized.", 403)  unless bet.user_id == current_user.id
    return render_error("Can only cancel pending bets.") unless bet.status == "pending"
    return render_error("Betting has closed — cannot cancel.") if bet.bookie_match.deadline_passed?

    refunded = false

    ActiveRecord::Base.transaction do
      # Atomically claim the bet: only the request that actually deletes the
      # row (1 row affected) is allowed to refund. Concurrent duplicate
      # cancels delete 0 rows and bail out, which prevents a double refund.
      deleted = BookieBet
        .where(id: bet.id, user_id: current_user.id, status: "pending")
        .delete_all

      if deleted.positive?
        wallet = BookieWallet.find_or_create_for_user(current_user.id)
        wallet.credit!(
          bet.amount,
          "Cancelled bet on: #{bet.bookie_match.title}",
          match_id: bet.match_id,
          type:     "bet_cancelled"
        )
        refunded = true
      end
    end

    if refunded
      render json: { success: true }
    else
      render_error("This bet was already cancelled or settled.")
    end
  rescue => e
    log_internal_error("cancel_bet", e)
    render_error("Could not cancel your bet right now.", 500)
  end

  # GET /bookie/accumulators
  def accumulators
    accas = BookieAccumulator
      .where(user_id: current_user.id)
      .includes(bookie_accumulator_legs: :bookie_match)
      .order(created_at: :desc)
      .limit(50)

    render json: {
      accumulators: accas.map { |a| serialize_accumulator(a) },
      currency:     bookie_currency
    }
  end

  # POST /bookie/accumulators
  def place_accumulator
    amount   = params[:amount].to_i
    raw_legs = params[:legs]
    raw_legs = raw_legs.values if raw_legs.respond_to?(:values) && !raw_legs.is_a?(Array)
    legs_input = Array(raw_legs)

    min_legs = BookieAccumulator::MIN_LEGS
    max_legs = BookieAccumulator.max_legs

    return render_error("Minimum stake is #{bookie_min_bet} coins.") if amount < bookie_min_bet
    return render_error("An accumulator needs at least #{min_legs} selections.") if legs_input.length < min_legs
    return render_error("An accumulator can have at most #{max_legs} selections.") if legs_input.length > max_legs

    seen = {}
    resolved = []
    legs_input.each do |leg|
      match_id = leg[:match_id].to_i
      choice   = leg[:choice].to_s

      return render_error("Invalid selection.") unless %w[home draw away].include?(choice)
      return render_error("The same event can't appear twice in one accumulator.") if seen[match_id]
      seen[match_id] = true

      match = BookieMatch.find_by(id: match_id)
      return render_error("One of the selected events no longer exists.") unless match
      return render_error("Betting is closed for #{match.title}.") unless match.can_bet?
      return render_error("Invalid selection.") if choice == "draw" && !match.has_draw?

      odds = match.odds_for(choice)
      return render_error("Invalid selection.") unless odds

      resolved << { match: match, choice: choice, odds: odds }
    end

    combined_odds    = resolved.reduce(1.0) { |product, leg| product * leg[:odds] }
    potential_payout = (amount * combined_odds).round

    wallet = BookieWallet.find_or_create_for_user(current_user.id)
    return render_error("Insufficient balance.") if wallet.balance < amount

    acc = nil
    ActiveRecord::Base.transaction do
      acc = BookieAccumulator.create!(
        user_id:          current_user.id,
        amount:           amount,
        combined_odds:    combined_odds,
        potential_payout: potential_payout,
        status:           "pending"
      )
      resolved.each do |leg|
        acc.bookie_accumulator_legs.create!(
          match_id: leg[:match].id,
          choice:   leg[:choice],
          odds:     leg[:odds]
        )
      end
      wallet.debit!(amount, "Accumulator (#{resolved.length} legs)", type: "acca_placed")
    end

    render json: {
      accumulator: serialize_accumulator(acc.reload),
      new_balance: wallet.reload.balance
    }
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  rescue => e
    log_internal_error("place_accumulator", e)
    render_error("Could not place your accumulator right now.", 500)
  end

  # DELETE /bookie/accumulators/:id
  def cancel_accumulator
    acc = BookieAccumulator.find(params[:id])

    return render_error("Not authorized.", 403) unless acc.user_id == current_user.id
    return render_error("This accumulator can no longer be cancelled.") unless acc.status == "pending"

    legs = acc.bookie_accumulator_legs.includes(:bookie_match).to_a
    not_cancellable = legs.any? do |leg|
      leg.status != "pending" || leg.bookie_match.nil? || leg.bookie_match.deadline_passed?
    end
    return render_error("Cancellation has closed — one or more events have started.") if not_cancellable

    refunded = false
    ActiveRecord::Base.transaction do
      claimed = BookieAccumulator
        .where(id: acc.id, user_id: current_user.id, status: "pending")
        .update_all(status: "cancelled")

      if claimed.positive?
        acc.bookie_accumulator_legs.update_all(status: "void")
        BookieWallet
          .find_or_create_for_user(current_user.id)
          .credit!(acc.amount, "Accumulator cancelled", type: "acca_cancelled")
        refunded = true
      end
    end

    if refunded
      render json: { success: true }
    else
      render_error("This accumulator was already cancelled or settled.")
    end
  rescue => e
    log_internal_error("cancel_accumulator", e)
    render_error("Could not cancel your accumulator right now.", 500)
  end

  private

  BOOKIE_CURRENCY_DEFAULT  = "coins"
  BOOKIE_MIN_BET_DEFAULT   = 10

  def bookie_currency
    currency = SiteSetting.bookie_currency_name rescue BOOKIE_CURRENCY_DEFAULT
    currency == "Coins" ? "coins" : currency
  end

  def bookie_min_bet
    SiteSetting.bookie_min_bet rescue BOOKIE_MIN_BET_DEFAULT
  end

  def ensure_bookie_enabled
    enabled = SiteSetting.bookie_enabled rescue true
    raise Discourse::NotFound unless enabled
  end

  def bookie_notifications_enabled?(user)
    user.custom_fields["bookie_notifications_enabled"] != "false"
  end

  def render_error(msg, status = 422)
    render json: { error: msg }, status: status
  end

  def log_internal_error(action, error)
    Rails.logger.error(
      "[discourse-bookie] #{action} failed for user #{current_user&.id}: #{error.class}: #{error.message}"
    )
  end

  def serialize_accumulator(acc)
    {
      id:               acc.id,
      amount:           acc.amount,
      combined_odds:    acc.combined_odds.to_f,
      potential_payout: acc.potential_payout,
      payout:           acc.payout,
      status:           acc.status,
      created_at:       acc.created_at.iso8601,
      settled_at:       acc.settled_at&.iso8601,
      legs:             acc.bookie_accumulator_legs.map { |leg| serialize_accumulator_leg(leg) }
    }
  end

  def serialize_accumulator_leg(leg)
    match = leg.bookie_match
    {
      match_id:     leg.match_id,
      choice:       leg.choice,
      odds:         leg.odds.to_f,
      status:       leg.status,
      home_team:    match&.home_team,
      away_team:    match&.away_team,
      title:        match&.title,
      result:       match&.result,
      choice_label: accumulator_choice_label(leg.choice, match)
    }
  end

  def accumulator_choice_label(choice, match)
    case choice
    when "home" then match&.home_team || "Home"
    when "away" then match&.away_team || "Away"
    else "Draw"
    end
  end

  def settled_match_scores_for(user_id, target_match_ids)
    target_ids = target_match_ids.each_with_object({}) { |match_id, memo| memo[match_id] = true }
    scores_by_match = {}
    streak_by_period = Hash.new(0)

    settled_bets = BookieBet
      .joins(:bookie_match)
      .where(user_id: user_id, status: %w[won lost])
      .where(bookie_matches: { status: "settled", sport: "football" })
      .select("bookie_bets.id, bookie_bets.match_id, bookie_bets.status, bookie_bets.odds, bookie_matches.updated_at AS settled_at")
      .order("bookie_matches.updated_at ASC, bookie_bets.id ASC")

    settled_bets.each do |bet|
      settled_at = bet.attributes["settled_at"] || bet.updated_at
      period_key = BookieLeagueEntry.period_for(settled_at.to_date)
      next unless period_key

      score_data = league_score_data_for_bet(
        won: bet.status == "won",
        odds: bet.odds,
        streak: streak_by_period[period_key]
      )

      streak_by_period[period_key] = score_data[:streak]
      if target_ids.key?(bet.match_id)
        scores_by_match[bet.match_id] = {
          total: score_data[:total],
          breakdown: score_data[:breakdown]
        }
      end
    end

    scores_by_match
  end

  def results_stats_for(user_id)
    settled_bets = BookieBet
      .includes(bookie_match: %i[home_club away_club])
      .joins(:bookie_match)
      .where(user_id: user_id, status: %w[won lost])
      .where(bookie_matches: { status: "settled" })
      .order("bookie_matches.updated_at ASC, bookie_bets.id ASC")

    league_point_transactions = BookieTransaction
      .left_joins(:bookie_match)
      .where(user_id: user_id, transaction_type: "league_points")
      .select(
        "bookie_transactions.id, bookie_transactions.match_id, bookie_transactions.amount, " \
        "bookie_transactions.created_at, bookie_matches.title AS match_title"
      )
      .order("bookie_transactions.created_at ASC, bookie_transactions.id ASC")

    balance_checkpoints = {}
    running_balance = 0
    BookieTransaction
      .where(user_id: user_id)
      .order(:created_at, :id)
      .select(:id, :match_id, :transaction_type, :amount, :created_at)
      .each do |tx|
        running_balance += tx.amount.to_i
        if tx.match_id && %w[bet_won bet_lost].include?(tx.transaction_type)
          balance_checkpoints[tx.match_id] = running_balance
        end
      end

    return default_results_stats if settled_bets.blank?

    periods_won = BookiePeriodSnapshot.where(user_id: user_id, rank: 1).count
    total_settled_bets = 0
    wins = 0
    losses = 0
    current_streak = 0
    best_streak = 0
    total_league_points = 0
    total_coin_delta = 0
    biggest_win = 0
    winning_odds_total = 0.0
    winning_odds_count = 0
    team_profit = Hash.new(0)
    team_bets = Hash.new(0)
    recent_form = []
    points_by_match_id = league_point_transactions.each_with_object({}) do |tx, memo|
      memo[tx.match_id] = tx.amount.to_i if tx.match_id
    end
    total_league_points = league_point_transactions.sum { |tx| tx.amount.to_i }
    timeline = []

    settled_bets.each do |bet|
      won = bet.status == "won"
      points = points_by_match_id[bet.match_id].to_i
      match = bet.bookie_match
      settled_at = match&.updated_at || bet.updated_at

      total_settled_bets += 1

      if won
        wins += 1
        current_streak += 1
        best_streak = [best_streak, current_streak].max
        winning_odds_total += bet.odds.to_f
        winning_odds_count += 1
      else
        losses += 1
        current_streak = 0
      end

      net_coin_delta = won ? (bet.payout.to_i - bet.amount.to_i) : -bet.amount.to_i
      total_coin_delta += net_coin_delta
      biggest_win = [biggest_win, net_coin_delta].max

      selected_team =
        case bet.choice
        when "home" then match&.home_canonical_name
        when "away" then match&.away_canonical_name
        end

      if selected_team.present?
        team_profit[selected_team] += net_coin_delta
        team_bets[selected_team] += 1
      end

      timeline << {
        label: match&.title,
        date: settled_at.iso8601,
        delta_points: net_coin_delta,
        cumulative_points: balance_checkpoints[bet.match_id].to_i,
        won: won
      }

      recent_form << {
        result: won ? "W" : "L",
        label: match&.title,
        delta_points: points,
        coin_delta: net_coin_delta
      }
    end

    best_team_name, best_team_profit =
      team_profit.max_by { |team, profit| [profit, team_bets[team], team] }

    {
      summary: {
        total_settled_bets: total_settled_bets,
        wins: wins,
        losses: losses,
        hit_rate: total_settled_bets.zero? ? 0 : ((wins.to_f / total_settled_bets) * 100).round,
        current_streak: current_streak,
        best_streak: best_streak,
        periods_won: periods_won,
        total_league_points: total_league_points,
        total_coin_delta: total_coin_delta,
        average_winning_odds: winning_odds_count.zero? ? nil : (winning_odds_total / winning_odds_count).round(2),
        biggest_win: biggest_win,
        best_team: best_team_name,
        best_team_profit: best_team_profit.to_i
      },
      recent_form: recent_form.last(10),
      wins_losses: [
        { label: "Correct", value: wins },
        { label: "Wrong", value: losses }
      ],
      points_timeline: timeline.last(20),
      achievements: BookieAchievements.payload_for(user_id)
    }
  end

  def default_results_stats
    {
      summary: {
        total_settled_bets: 0,
        wins: 0,
        losses: 0,
        hit_rate: 0,
        current_streak: 0,
        best_streak: 0,
        periods_won: 0,
        total_league_points: 0,
        total_coin_delta: 0,
        average_winning_odds: nil,
        biggest_win: 0,
        best_team: nil,
        best_team_profit: 0
      },
      recent_form: [],
      wins_losses: [
        { label: "Correct", value: 0 },
        { label: "Wrong", value: 0 }
      ],
      points_timeline: [],
      achievements: BookieAchievements.payload_for(nil)
    }
  end

  def league_score_data_for_bet(won:, odds:, streak:)
    breakdown = [{ points: 2, label: "participation" }]

    if won
      streak += 1
      breakdown << { points: 10, label: "correct pick" }

      odds_bonus = [(odds.to_f - 1) * 4, 0].max.round
      breakdown << { points: odds_bonus, label: "odds bonus" } if odds_bonus > 0

      if streak == 3
        breakdown << { points: 8, label: "winning streak (3 games)" }
      elsif streak == 5
        breakdown << { points: 18, label: "winning streak (5 games)" }
      elsif streak == 8
        breakdown << { points: 35, label: "winning streak (8 games)" }
      end
    else
      streak = 0
    end

    {
      streak: streak,
      total: breakdown.sum { |entry| entry[:points] },
      breakdown: breakdown
    }
  end

  def serialize_match(match, user_bet = nil, score_data = nil)
    total_bets = match.bookie_bets.count
    total_coins = match.bookie_bets.sum(:amount)

    {
      id:         match.id,
      title:      match.title,
      home_team:  match.home_team,
      away_team:  match.away_team,
      odds_home:  match.odds_home.to_f,
      odds_draw:  match.odds_draw&.to_f,
      odds_away:  match.odds_away.to_f,
      sport:      match.sport,
      sport_label: match.sport_label,
      sport_icon:  match.sport_icon,
      has_draw:   match.has_draw?,
      deadline:   match.deadline.iso8601,
      status:     match.status,
      result:     match.result,
      can_bet:    match.can_bet?,
      user_bet:   user_bet ? serialize_bet(user_bet) : nil,
      total_bets: total_bets,
      total_coins: total_coins,
      league_points: score_data&.dig(:total),
      league_points_breakdown: score_data&.dig(:breakdown)
    }
  end

  def serialize_bet(bet)
    {
      id:              bet.id,
      choice:          bet.choice,
      amount:          bet.amount,
      odds:            bet.odds.to_f,
      status:          bet.status,
      payout:          bet.payout,
      potential_payout: bet.potential_payout
    }
  end

  def serialize_transaction(t)
    {
      type:        t.transaction_type,
      amount:      t.amount,
      description: t.description,
      date:        t.created_at.iso8601
    }
  end
end
