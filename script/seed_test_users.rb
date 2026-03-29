# Seed script — creates test users with realistic bookie data.
#
# Usage (run from Discourse root):
#   bundle exec rails runner plugins/discourse-bookie/script/seed_test_users.rb
#
# Safe to re-run — skips users that already exist.

USERNAMES = %w[
  Bl1nk LukeTheGooner Tyers LFS-forward Gladiator JakeyBoy
  SRCJJ sevchenko SDGooner Truth_hurts Bavin BergkampsLoveChild
  Leper Jules MissRedNL Mr_Nostalgia shamrockgooner Electrifying
  Mercenary RockyMaivia Varunn Mondo
].freeze

STARTING = SiteSetting.bookie_starting_balance rescue 1000
period   = BookieLeagueEntry.current_period_key

puts "Creating #{USERNAMES.size} test users..."

USERNAMES.each_with_index do |username, i|
  # Sanitise username for Discourse (no hyphens allowed)
  safe_username = username.gsub("-", "_")

  user = User.find_by(username: safe_username)
  if user.nil?
    user = User.create!(
      username:              safe_username,
      email:                 "#{safe_username.downcase}@bookie-test.local",
      password:              "Discourse1!",
      name:                  safe_username,
      active:                true,
      approved:              true,
      trust_level:           1,
      skip_email_validation: true
    )
    puts "  Created user: #{safe_username}"
  else
    puts "  Skipped (exists): #{safe_username}"
  end

  # ── Wallet ──────────────────────────────────────────────
  wallet = BookieWallet.find_or_initialize_by(user_id: user.id)
  if wallet.new_record?
    # Spread balances realistically: some up, some down
    balance = STARTING + rand(-600..1800)
    balance = [balance, 50].max   # floor at 50 so no one's broke
    wallet.balance = balance
    wallet.save!
    BookieTransaction.create!(
      user_id:          user.id,
      transaction_type: "starting_balance",
      amount:           STARTING,
      description:      "Welcome! Starting balance"
    )
  end

  # ── League Table entry ───────────────────────────────────
  next unless period

  entry = BookieLeagueEntry.find_or_initialize_by(user_id: user.id, period_key: period)
  if entry.new_record?
    bets_placed    = rand(3..18)
    correct_picks  = rand(1..bets_placed)
    current_streak = rand(0..4)
    longest_streak = [current_streak + rand(0..3), correct_picks].min

    # Rough points: activity + correct pick base + some bonuses
    points = (bets_placed * 2) + (correct_picks * 10) + rand(0..40)

    entry.update!(
      bets_placed:    bets_placed,
      correct_picks:  correct_picks,
      points:         points,
      current_streak: current_streak,
      longest_streak: longest_streak
    )
  end

  # ── At least one settled bet (so user shows in Richest Gooner) ──
  match = BookieMatch.settled.first
  if match && !BookieBet.exists?(user_id: user.id, match_id: match.id)
    choice = %w[home draw away].sample
    amount = rand(50..300)
    won    = choice == match.result
    payout = won ? (amount * match.odds_for(choice)).round : 0
    BookieBet.create!(
      user_id:  user.id,
      match_id: match.id,
      choice:   choice,
      amount:   amount,
      odds:     match.odds_for(choice),
      status:   won ? "won" : "lost",
      payout:   payout
    )
  end
end

puts "\nDone! League Table and Richest Gooner are now populated."
puts "Visit /bookie → Standings to check the result."
