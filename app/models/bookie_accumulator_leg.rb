class BookieAccumulatorLeg < ActiveRecord::Base
  belongs_to :bookie_accumulator, foreign_key: :accumulator_id
  belongs_to :bookie_match, foreign_key: :match_id

  validates :accumulator_id, :match_id, :choice, :odds, presence: true
  validates :choice, inclusion: { in: %w[home draw away] }
  validates :status, inclusion: { in: %w[pending won lost void] }

  scope :pending, -> { where(status: "pending") }
end
