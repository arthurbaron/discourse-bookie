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
    settled_points = settled_match_points_for(current_user.id, settled_ids)

    render json: {
      matches:         open_matches.map { |m| serialize_match(m, user_bets[m.id]) },
      settled_matches: settled.map { |m| serialize_match(m, settled_bets[m.id], settled_points[m.id]) },
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
      balance:      wallet.balance,
      currency:     bookie_currency,
      transactions: transactions.map { |t| serialize_transaction(t) }
    }
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
      .sort_by { |p| p[:period_key] }
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
    return render_error("Invalid choice.") unless %w[home draw away].include?(choice)
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

    ActiveRecord::Base.transaction do
      wallet = BookieWallet.find_or_create_for_user(current_user.id)
      wallet.credit!(
        bet.amount,
        "Cancelled bet on: #{bet.bookie_match.title}",
        match_id: bet.match_id,
        type:     "bet_cancelled"
      )
      bet.destroy!
    end

    render json: { success: true }
  rescue => e
    log_internal_error("cancel_bet", e)
    render_error("Could not cancel your bet right now.", 500)
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

  def render_error(msg, status = 422)
    render json: { error: msg }, status: status
  end

  def log_internal_error(action, error)
    Rails.logger.error(
      "[discourse-bookie] #{action} failed for user #{current_user&.id}: #{error.class}: #{error.message}"
    )
  end

  def settled_match_points_for(user_id, match_ids)
    direct_points = BookieTransaction
      .where(user_id: user_id, transaction_type: "league_points", match_id: match_ids)
      .pluck(:match_id, :amount)
      .to_h

    missing_match_ids = match_ids - direct_points.keys
    return direct_points if missing_match_ids.empty?

    direct_points.merge(reconstructed_match_points_for(user_id, missing_match_ids))
  end

  def reconstructed_match_points_for(user_id, target_match_ids)
    target_ids = target_match_ids.each_with_object({}) { |match_id, memo| memo[match_id] = true }
    points_by_match = {}
    streak_by_period = Hash.new(0)

    settled_bets = BookieBet
      .joins(:bookie_match)
      .where(user_id: user_id, status: %w[won lost])
      .where(bookie_matches: { status: "settled" })
      .select("bookie_bets.id, bookie_bets.match_id, bookie_bets.status, bookie_bets.odds, bookie_matches.updated_at AS settled_at")
      .order("bookie_matches.updated_at ASC, bookie_bets.id ASC")

    settled_bets.each do |bet|
      settled_at = bet.attributes["settled_at"] || bet.updated_at
      period_key = BookieLeagueEntry.period_for(settled_at.to_date)
      next unless period_key

      won = bet.status == "won"
      streak = streak_by_period[period_key]
      pts = 2

      if won
        streak += 1
        pts += 10
        pts += [(bet.odds.to_f - 1) * 4, 0].max.round
        pts += 8  if streak == 3
        pts += 18 if streak == 5
        pts += 35 if streak == 8
      else
        streak = 0
      end

      streak_by_period[period_key] = streak
      points_by_match[bet.match_id] = pts if target_ids.key?(bet.match_id)
    end

    points_by_match
  end

  def serialize_match(match, user_bet = nil, points_amount = nil)
    {
      id:         match.id,
      title:      match.title,
      home_team:  match.home_team,
      away_team:  match.away_team,
      odds_home:  match.odds_home.to_f,
      odds_draw:  match.odds_draw.to_f,
      odds_away:  match.odds_away.to_f,
      deadline:   match.deadline.iso8601,
      status:     match.status,
      result:     match.result,
      can_bet:    match.can_bet?,
      user_bet:   user_bet ? serialize_bet(user_bet) : nil,
      league_points: points_amount
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
