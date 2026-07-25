class BookieSprintSnapshot < ActiveRecord::Base
  belongs_to :user

  scope :for_month, ->(month_key) { where(month_key: month_key).order(:rank) }
end
