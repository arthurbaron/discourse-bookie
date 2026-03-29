class AdminBookieController < Admin::AdminController
  before_action :find_match, only: %i[update_match destroy_match settle_match]

  # GET /admin/plugins/bookie/matches
  def matches
    open_matches    = BookieMatch.unsettled
    settled_matches = BookieMatch.settled.limit(20)

    render json: {
      matches:         open_matches.map { |m| serialize_match(m) },
      settled_matches: settled_matches.map { |m| serialize_match(m) }
    }
  end

  # POST /admin/plugins/bookie/matches
  def create_match
    match = BookieMatch.new(match_params)

    if match.save
      render json: { match: serialize_match(match) }
    else
      render json: { errors: match.errors.full_messages }, status: 422
    end
  end

  # PUT /admin/plugins/bookie/matches/:id
  def update_match
    if @match.update(match_params)
      render json: { match: serialize_match(@match) }
    else
      render json: { errors: @match.errors.full_messages }, status: 422
    end
  end

  # DELETE /admin/plugins/bookie/matches/:id
  def destroy_match
    if @match.status == "settled"
      return render json: { error: "Cannot delete a settled match." }, status: 422
    end

    # Refund pending bets
    @match.bookie_bets.where(status: "pending").each do |bet|
      wallet = BookieWallet.find_or_create_for_user(bet.user_id)
      wallet.credit!(
        bet.amount,
        "Match cancelled: #{@match.title}",
        match_id: @match.id,
        type:     "bet_cancelled"
      )
    end

    @match.destroy!
    render json: { success: true }
  end

  # POST /admin/plugins/bookie/matches/:id/settle
  def settle_match
    result = params[:result].to_s

    unless %w[home draw away].include?(result)
      return render json: { error: "Invalid result. Must be home, draw or away." }, status: 422
    end

    if @match.settle!(result)
      render json: { match: serialize_match(@match.reload) }
    else
      render json: { error: "Could not settle match." }, status: 422
    end
  end

  # GET /admin/plugins/bookie/season
  def season_status
    season_key = BookieSeasonSnapshot.current_season_key
    existing   = BookieSeasonSnapshot.where(season_key: season_key).exists?
    past       = BookieSeasonSnapshot
      .select(:season_key)
      .distinct
      .order(season_key: :desc)
      .limit(5)
      .pluck(:season_key)

    render json: {
      current_season_key: season_key,
      already_closed:     existing,
      past_seasons:       past
    }
  end

  # POST /admin/plugins/bookie/season/end
  def end_season
    season_key = BookieSeasonSnapshot.current_season_key

    if BookieSeasonSnapshot.where(season_key: season_key).exists?
      return render json: { error: "Season #{season_key} has already been closed." }, status: 422
    end

    BookieSeasonSnapshot.close_season!(season_key)
    render json: { success: true, season_key: season_key }
  rescue => e
    render json: { error: e.message }, status: 500
  end

  private

  def find_match
    @match = BookieMatch.find(params[:id])
  end

  def match_params
    params.require(:match).permit(
      :title, :home_team, :away_team,
      :odds_home, :odds_draw, :odds_away,
      :deadline
    )
  end

  def serialize_match(match)
    total_bets  = match.bookie_bets.count
    total_coins = match.bookie_bets.sum(:amount)

    bets_by_choice = match.bookie_bets.group(:choice).count

    {
      id:           match.id,
      title:        match.title,
      home_team:    match.home_team,
      away_team:    match.away_team,
      odds_home:    match.odds_home.to_f,
      odds_draw:    match.odds_draw.to_f,
      odds_away:    match.odds_away.to_f,
      deadline:     match.deadline.iso8601,
      status:       match.status,
      result:       match.result,
      total_bets:   total_bets,
      total_coins:  total_coins,
      bets_home:    bets_by_choice["home"] || 0,
      bets_draw:    bets_by_choice["draw"] || 0,
      bets_away:    bets_by_choice["away"] || 0
    }
  end
end
