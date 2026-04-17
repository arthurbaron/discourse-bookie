class BookieClub < ActiveRecord::Base
  has_many :bookie_club_aliases, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  before_validation :ensure_slug

  def all_names
    ([name] + bookie_club_aliases.pluck(:name)).uniq
  end

  private

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
