# Run this migration BEFORE removing the plugin to cleanly drop all bookie data.
#
# Usage:
#   bundle exec rails db:migrate VERSION=20260329000099
#
# After running, you can safely delete the plugin directory.
# WARNING: This permanently deletes all bookie data — matches, bets, wallets,
# transactions, standings, and snapshots. There is no undo.

class DropBookieTables < ActiveRecord::Migration[7.0]
  def up
    drop_table :bookie_season_snapshots,  if_exists: true
    drop_table :bookie_period_snapshots,  if_exists: true
    drop_table :bookie_league_entries,    if_exists: true
    drop_table :bookie_monthly_snapshots, if_exists: true
    drop_table :bookie_transactions,      if_exists: true
    drop_table :bookie_bets,              if_exists: true
    drop_table :bookie_wallets,           if_exists: true
    drop_table :bookie_matches,           if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot restore bookie tables — re-install the plugin and run db:migrate instead."
  end
end
