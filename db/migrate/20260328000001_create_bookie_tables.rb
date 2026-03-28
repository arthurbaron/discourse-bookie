class CreateBookieTables < ActiveRecord::Migration[7.0]
  def change
    create_table :bookie_matches do |t|
      t.string  :title,      null: false
      t.string  :home_team,  null: false
      t.string  :away_team,  null: false
      t.decimal :odds_home,  precision: 5, scale: 2, null: false, default: 1.90
      t.decimal :odds_draw,  precision: 5, scale: 2, null: false, default: 3.50
      t.decimal :odds_away,  precision: 5, scale: 2, null: false, default: 4.00
      t.datetime :deadline,  null: false
      t.string  :result      # 'home', 'draw', 'away' — null until settled
      t.string  :status,     null: false, default: "open"  # open, settled
      t.timestamps
    end

    create_table :bookie_wallets do |t|
      t.integer :user_id, null: false
      t.integer :balance, null: false, default: 1000
      t.timestamps
    end
    add_index :bookie_wallets, :user_id, unique: true

    create_table :bookie_bets do |t|
      t.integer :user_id,  null: false
      t.integer :match_id, null: false
      t.string  :choice,   null: false   # 'home', 'draw', 'away'
      t.integer :amount,   null: false
      t.decimal :odds,     precision: 5, scale: 2, null: false
      t.integer :payout    # null = pending, 0 = lost, >0 = won
      t.string  :status,   null: false, default: "pending"  # pending, won, lost
      t.timestamps
    end
    add_index :bookie_bets, [:user_id, :match_id], unique: true
    add_index :bookie_bets, :match_id

    create_table :bookie_transactions do |t|
      t.integer :user_id,          null: false
      t.string  :transaction_type, null: false
      t.integer :amount,           null: false
      t.string  :description
      t.integer :match_id
      t.timestamps
    end
    add_index :bookie_transactions, :user_id
    add_index :bookie_transactions, :created_at

    create_table :bookie_monthly_snapshots do |t|
      t.integer :user_id,       null: false
      t.integer :month,         null: false
      t.integer :year,          null: false
      t.integer :final_balance, null: false
      t.integer :rank
      t.timestamps
    end
    add_index :bookie_monthly_snapshots, [:user_id, :year, :month], unique: true
    add_index :bookie_monthly_snapshots, [:year, :month]
  end
end
