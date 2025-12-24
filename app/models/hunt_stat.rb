class HuntStat < ApplicationRecord
    SPECIES_OPTIONS = ["ELK"].freeze
    SEX_OPTIONS = ["M", "F", "E"].freeze
    METHOD_OPTIONS = ["Archery", "Muzzleloader", "Rifle"].freeze

    validates :species, inclusion: { in: SPECIES_OPTIONS }, allow_blank: true
    validates :sex,     inclusion: { in: SEX_OPTIONS }, allow_blank: true
    # validates :season,  inclusion: { in: SEASON_OPTIONS }, allow_blank: true
    validates :hunt_method,  inclusion: { in: METHOD_OPTIONS }, allow_blank: true
end
