class BookiePeriodSnapshot < ActiveRecord::Base
  belongs_to :user

  scope :for_period, ->(period_key) { where(period_key: period_key).order(:rank) }

  def self.previous_period_key
    today = Date.today
    # Go back far enough to land in the previous period
    BookieLeagueEntry.period_for(today - 65)
  end
end
