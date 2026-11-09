class CalendarEvent < ApplicationRecord
  KIND_LABELS = {
    "deadline" => "Deadline",
    "draw_results" => "Draw results",
    "leftover" => "Leftover licenses",
    "season" => "Season",
    "reminder" => "Reminder"
  }.freeze
  KINDS = KIND_LABELS.keys.freeze

  belongs_to :user, optional: true

  before_validation { self.species = species.presence }

  validates :title, presence: true
  validates :starts_on, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :state, inclusion: { in: Profile::STATES.keys }
  validates :species, inclusion: { in: HuntStat::SPECIES_OPTIONS }, allow_nil: true
  validate :ends_on_not_before_starts_on
  validate :user_matches_kind

  scope :between, ->(from, to) { where("starts_on <= ? AND COALESCE(ends_on, starts_on) >= ?", to, from) }
  scope :visible_to, ->(user) { where(user_id: [nil, user.id]) }
  scope :for_species, ->(list) { list.blank? ? all : where(species: [nil, *list]) }
  scope :chronological, -> { order(:starts_on, :id) }

  private

  def ends_on_not_before_starts_on
    return if ends_on.blank? || starts_on.blank?
    errors.add(:ends_on, "can't be before the start date") if ends_on < starts_on
  end

  # Reminders belong to a user; every other kind is a public event.
  def user_matches_kind
    return if (kind == "reminder") == user_id.present?
    errors.add(:user, kind == "reminder" ? "is required for reminders" : "must be blank for public events")
  end
end
