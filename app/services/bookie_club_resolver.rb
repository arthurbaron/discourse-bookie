class BookieClubResolver
  CLUB_ALIASES = {
    "Man City" => ["Manchester City", "Manchester C.", "Man. City"],
    "Man Utd" => ["Manchester United", "Manchester Utd", "Man United", "Man United FC"],
    "Spurs" => ["Tottenham", "Tottenham Hotspur"],
    "Newcastle" => ["Newcastle United"],
    "Wolves" => ["Wolverhampton Wanderers"],
    "West Ham" => ["West Ham United"],
    "Brighton" => ["Brighton & Hove Albion", "Brighton and Hove Albion"],
    "Forest" => ["Nottingham Forest"],
    "Leicester" => ["Leicester City"],
    "Ipswich" => ["Ipswich Town"],
    "Southampton" => ["Southampton FC"],
    "Bournemouth" => ["AFC Bournemouth", "Bournemouth AFC"],
    "PSG" => ["Paris Saint-Germain", "Paris SG"],
    "Inter" => ["Inter Milan", "Internazionale"],
    "AC Milan" => ["Milan", "A.C. Milan"],
    "Atletico" => ["Atletico Madrid", "Atlético Madrid"],
    "Bayern" => ["Bayern Munich", "FC Bayern München", "FC Bayern Munich"],
    "Dortmund" => ["Borussia Dortmund", "BVB"],
    "Leverkusen" => ["Bayer Leverkusen"],
    "Juventus" => ["Juventus FC"],
    "Roma" => ["AS Roma"],
    "Lazio" => ["SS Lazio"],
    "Napoli" => ["SSC Napoli"],
    "Ajax" => ["AFC Ajax"],
    "PSV" => ["PSV Eindhoven"],
    "Feyenoord" => ["Feyenoord Rotterdam"],
    "AZ" => ["AZ Alkmaar"],
    "Twente" => ["FC Twente"],
    "NEC" => ["N.E.C.", "NEC Nijmegen"],
    "Go Ahead Eagles" => ["GA Eagles", "Go Ahead"],
    "Heerenveen" => ["SC Heerenveen"],
    "Willem II" => ["Willem II Tilburg"],
  }.freeze

  Result = Struct.new(:club, :canonical_name, keyword_init: true)

  def self.canonical_name_for(input)
    new.canonical_name_for(input)
  end

  def self.find_or_create!(input)
    new.find_or_create!(input)
  end

  def self.backfill_match!(match)
    new.backfill_match!(match)
  end

  def canonical_name_for(input)
    normalized = normalize(input)
    return nil if normalized.blank?

    alias_map.each do |canonical, names|
      return canonical if names.include?(normalized)
    end

    normalized
  end

  def find_or_create!(input)
    canonical_name = canonical_name_for(input)
    return Result.new(club: nil, canonical_name: nil) if canonical_name.blank?

    club =
      BookieClub.find_by("LOWER(name) = ?", canonical_name.downcase) ||
      BookieClub.joins(:bookie_club_aliases).find_by("LOWER(bookie_club_aliases.name) = ?", canonical_name.downcase)

    club ||= BookieClub.create!(name: canonical_name, slug: canonical_name.parameterize)

    ensure_aliases!(club, canonical_name)

    input_name = normalize(input)
    if input_name.present? && input_name.casecmp(club.name) != 0
      BookieClubAlias.find_or_create_by!(bookie_club: club, name: input_name)
    end

    Result.new(club: club, canonical_name: club.name)
  end

  def backfill_match!(match)
    home = find_or_create!(match.home_team)
    away = find_or_create!(match.away_team)

    attrs = {
      home_club_id: home.club&.id,
      away_club_id: away.club&.id,
      home_team: home.canonical_name || match.home_team,
      away_team: away.canonical_name || match.away_team,
    }

    simple_title_before = "#{match.home_team} vs #{match.away_team}"
    if match.title.blank? || match.title == simple_title_before
      attrs[:title] = "#{attrs[:home_team]} vs #{attrs[:away_team]}"
    end

    match.update_columns(attrs) if attrs.compact.any?
  end

  private

  def ensure_aliases!(club, canonical_name)
    aliases = CLUB_ALIASES[canonical_name] || []
    aliases.each do |name|
      BookieClubAlias.find_or_create_by!(bookie_club: club, name: name)
    end
  end

  def normalize(value)
    value.to_s.strip.gsub(/\s+/, " ")
  end

  def alias_map
    @alias_map ||= begin
      CLUB_ALIASES.each_with_object({}) do |(canonical, aliases), memo|
        memo[canonical] = ([canonical] + aliases).map { |name| normalize(name) }.uniq
      end
    end
  end
end
