class Profile < ApplicationRecord
  STATES = {
    "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas", "CA" => "California",
    "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware", "FL" => "Florida", "GA" => "Georgia",
    "HI" => "Hawaii", "ID" => "Idaho", "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa",
    "KS" => "Kansas", "KY" => "Kentucky", "LA" => "Louisiana", "ME" => "Maine", "MD" => "Maryland",
    "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi", "MO" => "Missouri",
    "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada", "NH" => "New Hampshire", "NJ" => "New Jersey",
    "NM" => "New Mexico", "NY" => "New York", "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio",
    "OK" => "Oklahoma", "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina",
    "SD" => "South Dakota", "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah", "VT" => "Vermont",
    "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia", "WI" => "Wisconsin", "WY" => "Wyoming"
  }.freeze
  # States offered as "interested in" checkboxes in the form.
  TRACKABLE_STATES = %w[CO WY MT ID UT NM AZ NV OR WA].freeze
  # States that actually have draw data today.
  AVAILABLE_STATES = %w[CO].freeze

  ARRAY_ATTRIBUTES = %i[favorite_species states_of_interest preferred_methods].freeze

  belongs_to :user
  has_many :preference_points, dependent: :destroy
  accepts_nested_attributes_for :preference_points, reject_if: ->(attrs) { attrs["points"].blank? }

  before_validation :normalize

  validates :name, presence: true
  validates :user_id, uniqueness: true
  validates :residency_state, inclusion: { in: STATES.keys }, allow_blank: true
  validate :array_values_allowed

  def points_for(species)
    preference_points.find { |point| point.species == species }&.points
  end

  def residency_label
    "#{STATES[residency_state]} resident" if residency_state.present?
  end

  private

  def normalize
    ARRAY_ATTRIBUTES.each { |attr| self[attr] = Array(self[attr]).compact_blank.uniq }
    self.resident = residency_state.present? ? residency_state == "CO" : nil
  end

  def array_values_allowed
    check_subset(:favorite_species, HuntStat::SPECIES_OPTIONS)
    check_subset(:preferred_methods, HuntStat::METHOD_OPTIONS)
    check_subset(:states_of_interest, STATES.keys)
  end

  def check_subset(attr, allowed)
    invalid = self[attr] - allowed
    errors.add(attr, "includes invalid values: #{invalid.join(', ')}") if invalid.any?
  end
end
