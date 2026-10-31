# One row per (hunt_code, residency, preference tier, weighted level) from a
# weighted-draw post-draw report. Species with a weighted draw (see
# HuntStat::WEIGHTED_SPECIES) keep this detail here; hunt_stats holds the same
# data summed per preference level.
class WeightedStat < ApplicationRecord
  validates :hunt_code, presence: true
  validates :preference_points, :weighted_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :applicants, :success, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :success_not_above_applicants

  private

  def success_not_above_applicants
    errors.add(:success, "cannot exceed applicants") if applicants && success && success > applicants
  end
end
