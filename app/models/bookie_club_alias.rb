class BookieClubAlias < ActiveRecord::Base
  belongs_to :bookie_club

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :bookie_club, presence: true
end
