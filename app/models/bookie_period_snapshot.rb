class BookiePeriodSnapshot < ActiveRecord::Base
  belongs_to :user

  scope :for_period, ->(period_key) { where(period_key: period_key).order(:rank) }

  def self.previous_period_key
    today = Date.today
    current = BookieLeagueEntry.current_period_key
    return nil unless current

    # Find the first month of the current period, step back one day
    # to reliably land in the last day of the previous period.
    period = BookieLeagueEntry::PERIODS.find do |p|
      p[:months].include?(today.month)
    end
    return nil unless period

    first_month = period[:months].min
    # For Dec-Jan, December is the first month
    first_month = 12 if period[:months] == [12, 1]
    year = (first_month == 12 && today.month == 1) ? today.year - 1 : today.year

    start_of_current = Date.new(year, first_month, 1)
    BookieLeagueEntry.period_for(start_of_current - 1)
  end
end
