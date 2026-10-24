class PreferencePoint < ApplicationRecord
  belongs_to :profile

  validates :species, inclusion: { in: HuntStat::SPECIES_OPTIONS }
  validates :species, uniqueness: { scope: :profile_id }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 99 }
end
