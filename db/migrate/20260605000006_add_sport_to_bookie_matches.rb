class AddSportToBookieMatches < ActiveRecord::Migration[7.0]
  def change
    add_column :bookie_matches, :sport, :string, null: false, default: "football"
    # 2-outcome sports (boxing, tennis) have no draw, so draw odds may be blank.
    change_column_null :bookie_matches, :odds_draw, true
  end
end
