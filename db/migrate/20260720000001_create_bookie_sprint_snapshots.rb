class CreateBookieSprintSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :bookie_sprint_snapshots do |t|
      t.string  :month_key, null: false   # e.g. "2026-08"
      t.integer :user_id,   null: false
      t.integer :rank,      null: false
      t.integer :profit,    null: false   # net coin profit that month
      t.timestamps
    end

    add_index :bookie_sprint_snapshots, [:month_key, :rank]
    add_index :bookie_sprint_snapshots, [:month_key, :user_id], unique: true
  end
end
