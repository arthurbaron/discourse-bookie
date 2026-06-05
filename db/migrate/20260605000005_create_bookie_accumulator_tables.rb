class CreateBookieAccumulatorTables < ActiveRecord::Migration[7.0]
  def change
    create_table :bookie_accumulators do |t|
      t.integer  :user_id,          null: false
      t.integer  :amount,           null: false                       # stake
      t.decimal  :combined_odds,    precision: 12, scale: 2, null: false  # product of leg odds — can exceed 100
      t.integer  :potential_payout, null: false                       # round(amount * combined_odds) at placement
      t.integer  :payout            # null = pending, 0 = lost/void, > 0 = won
      t.string   :status,           null: false, default: "pending"   # pending, won, lost, cancelled, void
      t.datetime :settled_at
      t.timestamps
    end
    add_index :bookie_accumulators, [:user_id, :status]

    create_table :bookie_accumulator_legs do |t|
      t.integer :accumulator_id, null: false
      t.integer :match_id,       null: false
      t.string  :choice,         null: false   # home, draw, away
      t.decimal :odds,           precision: 5, scale: 2, null: false  # locked at placement
      t.string  :status,         null: false, default: "pending"      # pending, won, lost, void
      t.timestamps
    end
    add_index :bookie_accumulator_legs, :match_id
    add_index :bookie_accumulator_legs, [:accumulator_id, :match_id], unique: true
  end
end
