class AddBookieClubs < ActiveRecord::Migration[7.0]
  def change
    create_table :bookie_clubs do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    create_table :bookie_club_aliases do |t|
      t.references :bookie_club, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.timestamps
    end

    add_reference :bookie_matches, :home_club, foreign_key: { to_table: :bookie_clubs }, index: true
    add_reference :bookie_matches, :away_club, foreign_key: { to_table: :bookie_clubs }, index: true

    add_index :bookie_clubs, :name, unique: true
    add_index :bookie_clubs, :slug, unique: true
    add_index :bookie_club_aliases, :name, unique: true
  end
end
