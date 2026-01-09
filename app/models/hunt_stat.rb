class HuntStat < ApplicationRecord
    SPECIES_OPTIONS = %w[Elk Bear Deer Antelope].freeze
    SEX_OPTIONS = %w[M F E].freeze
    SEX_LABELS = { "M" => "Male", "F" => "Female", "E" => "Either" }.freeze
    METHOD_OPTIONS = %w[Archery Muzzleloader Rifle].freeze
    RESIDENT_OPTIONS = [["Resident", "true"], ["Non-Resident", "false"]].freeze

    validates :species, inclusion: { in: SPECIES_OPTIONS }, allow_blank: true
    validates :sex,     inclusion: { in: SEX_OPTIONS }, allow_blank: true
    validates :hunt_method,  inclusion: { in: METHOD_OPTIONS }, allow_blank: true

    # Helper for select dropdowns with display labels
    def self.sex_options_for_select
      SEX_OPTIONS.map { |code| [SEX_LABELS[code], code] }
    end
end
