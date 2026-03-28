class CreateBookieLeagueTables < ActiveRecord::Migration[7.0]
  def change
    # Per-user points tracking per period (e.g. "aug-sep-2026")
    create_table :bookie_league_entries do |t|
      t.integer :user_id,         null: false
      t.string  :period_key,      null: false   # e.g. "aug-sep-2026"
      t.integer :points,          null: false, default: 0
      t.integer :bets_placed,     null: false, default: 0
      t.integer :correct_picks,   null: false, default: 0
      t.integer :current_streak,  null: false, default: 0
      t.integer :longest_streak,  null: false, default: 0
      t.timestamps
    end
    add_index :bookie_league_entries, [:user_id, :period_key], unique: true
    add_index :bookie_league_entries, :period_key

    # Snapshot of top-3 at end of each period
    create_table :bookie_period_snapshots do |t|
      t.string  :period_key,  null: false
      t.integer :user_id,     null: false
      t.integer :rank,        null: false
      t.integer :points,      null: false
      t.timestamps
    end
    add_index :bookie_period_snapshots, [:period_key, :rank]
    add_index :bookie_period_snapshots, [:period_key, :user_id], unique: true
  end
end
