class AddCompetitionToBookieMatches < ActiveRecord::Migration[7.0]
  def change
    # Optional free-text label shown subtly on the event card (e.g. "FA Cup",
    # "Champions League"). Left blank for the default (mostly Premier League).
    add_column :bookie_matches, :competition, :string
  end
end
