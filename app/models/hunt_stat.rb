class HuntStat < ApplicationRecord
    SPECIES_OPTIONS = %w[Elk Deer Pronghorn].freeze
    SEX_OPTIONS = %w[M F E].freeze
    SEX_LABELS = { "M" => "Male", "F" => "Female", "E" => "Either" }.freeze
    METHOD_OPTIONS = %w[Archery Muzzleloader Rifle].freeze
    SEASON_OPTIONS = %w[E1 O1 O2 O3 O4 L1 P1 P2 P3 P4 P5 P6 W1 W2 W3 W4 W5 W6].freeze
    RESIDENT_OPTIONS = [["Resident", "true"], ["Non-Resident", "false"]].freeze

    validates :species, inclusion: { in: SPECIES_OPTIONS }, allow_blank: true
    validates :sex,     inclusion: { in: SEX_OPTIONS }, allow_blank: true
    validates :hunt_method,  inclusion: { in: METHOD_OPTIONS }, allow_blank: true

    # Helper for select dropdowns with display labels
    def self.sex_options_for_select
      SEX_OPTIONS.map { |code| [SEX_LABELS[code], code] }
    end
end
