class RecreateBookieTablesAfterBadDrop < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:bookie_matches)
      create_table :bookie_matches do |t|
        t.string  :title,      null: false
        t.string  :home_team,  null: false
        t.string  :away_team,  null: false
        t.decimal :odds_home,  precision: 5, scale: 2, null: false, default: 1.90
        t.decimal :odds_draw,  precision: 5, scale: 2, null: false, default: 3.50
        t.decimal :odds_away,  precision: 5, scale: 2, null: false, default: 4.00
        t.datetime :deadline,  null: false
        t.string  :result
        t.string  :status,     null: false, default: "open"
        t.timestamps
      end
    end

    unless table_exists?(:bookie_wallets)
      create_table :bookie_wallets do |t|
        t.integer :user_id, null: false
        t.integer :balance, null: false, default: 1000
        t.timestamps
      end
    end
    add_index :bookie_wallets, :user_id, unique: true unless index_exists?(:bookie_wallets, :user_id, unique: true)

    unless table_exists?(:bookie_bets)
      create_table :bookie_bets do |t|
        t.integer :user_id,  null: false
        t.integer :match_id, null: false
        t.string  :choice,   null: false
        t.integer :amount,   null: false
        t.decimal :odds,     precision: 5, scale: 2, null: false
        t.integer :payout
        t.string  :status,   null: false, default: "pending"
        t.timestamps
      end
    end
    add_index :bookie_bets, [:user_id, :match_id], unique: true unless index_exists?(:bookie_bets, [:user_id, :match_id], unique: true)
    add_index :bookie_bets, :match_id unless index_exists?(:bookie_bets, :match_id)

    unless table_exists?(:bookie_transactions)
      create_table :bookie_transactions do |t|
        t.integer :user_id,          null: false
        t.string  :transaction_type, null: false
        t.integer :amount,           null: false
        t.string  :description
        t.integer :match_id
        t.timestamps
      end
    end
    add_index :bookie_transactions, :user_id unless index_exists?(:bookie_transactions, :user_id)
    add_index :bookie_transactions, :created_at unless index_exists?(:bookie_transactions, :created_at)

    unless table_exists?(:bookie_monthly_snapshots)
      create_table :bookie_monthly_snapshots do |t|
        t.integer :user_id,       null: false
        t.integer :month,         null: false
        t.integer :year,          null: false
        t.integer :final_balance, null: false
        t.integer :rank
        t.timestamps
      end
    end
    add_index :bookie_monthly_snapshots, [:user_id, :year, :month], unique: true unless index_exists?(:bookie_monthly_snapshots, [:user_id, :year, :month], unique: true)
    add_index :bookie_monthly_snapshots, [:year, :month] unless index_exists?(:bookie_monthly_snapshots, [:year, :month])

    unless table_exists?(:bookie_league_entries)
      create_table :bookie_league_entries do |t|
        t.integer :user_id,         null: false
        t.string  :period_key,      null: false
        t.integer :points,          null: false, default: 0
        t.integer :bets_placed,     null: false, default: 0
        t.integer :correct_picks,   null: false, default: 0
        t.integer :current_streak,  null: false, default: 0
        t.integer :longest_streak,  null: false, default: 0
        t.timestamps
      end
    end
    add_index :bookie_league_entries, [:user_id, :period_key], unique: true unless index_exists?(:bookie_league_entries, [:user_id, :period_key], unique: true)
    add_index :bookie_league_entries, :period_key unless index_exists?(:bookie_league_entries, :period_key)

    unless table_exists?(:bookie_period_snapshots)
      create_table :bookie_period_snapshots do |t|
        t.string  :period_key,  null: false
        t.integer :user_id,     null: false
        t.integer :rank,        null: false
        t.integer :points,      null: false
        t.timestamps
      end
    end
    add_index :bookie_period_snapshots, [:period_key, :rank] unless index_exists?(:bookie_period_snapshots, [:period_key, :rank])
    add_index :bookie_period_snapshots, [:period_key, :user_id], unique: true unless index_exists?(:bookie_period_snapshots, [:period_key, :user_id], unique: true)

    unless table_exists?(:bookie_season_snapshots)
      create_table :bookie_season_snapshots do |t|
        t.string  :season_key, null: false
        t.integer :user_id,    null: false
        t.integer :rank,       null: false
        t.integer :balance,    null: false
        t.timestamps
      end
    end
    add_index :bookie_season_snapshots, [:season_key, :rank] unless index_exists?(:bookie_season_snapshots, [:season_key, :rank])
    add_index :bookie_season_snapshots, [:season_key, :user_id], unique: true unless index_exists?(:bookie_season_snapshots, [:season_key, :user_id], unique: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "This recovery migration should not be rolled back automatically."
  end
end
