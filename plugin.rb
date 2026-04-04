# name: discourse-bookie
# about: Virtual betting system - bet coins on football matches
# version: 0.1.0
# authors: Online Arsenal Community
# url: https://github.com/arthurbaron/discourse-bookie

register_asset "stylesheets/bookie.css"
register_svg_icon "trophy"

after_initialize do
  [
    "app/models/bookie_match",
    "app/models/bookie_wallet",
    "app/models/bookie_bet",
    "app/models/bookie_transaction",
    "app/services/bookie_notifier",
    "app/models/bookie_league_entry",
    "app/models/bookie_period_snapshot",
    "app/models/bookie_season_snapshot",
    "app/controllers/bookie_page_controller",
    "app/controllers/bookie_controller",
    "app/controllers/admin_bookie_controller",
  ].each { |f| require_relative f }

  # Prepend ALL routes so they win before Discourse's catch-all
  Discourse::Application.routes.prepend do
    # Ember app shell
    get "/bookie" => "bookie_page#index"

    # Public API
    get    "/bookie/matches"    => "bookie#matches"
    get    "/bookie/wallet"     => "bookie#wallet"
    get    "/bookie/leaderboard" => "bookie#leaderboard"
    post   "/bookie/bets"       => "bookie#place_bet"
    delete "/bookie/bets/:id"   => "bookie#cancel_bet"

    # Admin API
    scope "/admin/plugins/bookie", constraints: StaffConstraint.new do
      get    "/matches"            => "admin_bookie#matches"
      post   "/matches"            => "admin_bookie#create_match"
      post   "/grant-all"          => "admin_bookie#grant_all"
      post   "/period/close"       => "admin_bookie#close_period"
      put    "/matches/:id"        => "admin_bookie#update_match"
      delete "/matches/:id"        => "admin_bookie#destroy_match"
      post   "/matches/:id/settle" => "admin_bookie#settle_match"
      get    "/season"             => "admin_bookie#season_status"
      post   "/season/end"         => "admin_bookie#end_season"
    end
  end
end
