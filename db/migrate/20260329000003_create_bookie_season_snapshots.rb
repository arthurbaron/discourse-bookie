class CreateBookieSeasonSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :bookie_season_snapshots do |t|
      t.string  :season_key, null: false   # e.g. "2025-26"
      t.integer :user_id,    null: false
      t.integer :rank,       null: false
      t.integer :balance,    null: false
      t.timestamps
    end
    add_index :bookie_season_snapshots, [:season_key, :rank]
    add_index :bookie_season_snapshots, [:season_key, :user_id], unique: true
  end
end
