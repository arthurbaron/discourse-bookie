namespace :bookie do
  desc "Backfill canonical clubs for existing Bookie events"
  task backfill_clubs: :environment do
    total = 0

    BookieMatch.find_each do |match|
      BookieClubResolver.backfill_match!(match)
      total += 1
    end

    puts "Backfilled canonical clubs for #{total} Bookie events."
  end
end
