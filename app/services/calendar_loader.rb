# Loads public (non-user) calendar events from db/calendar/*.yml. Idempotent: an
# event is matched on state/kind/species/starts_on/title and updated in place.
class CalendarLoader
  def self.default_paths
    Dir[Rails.root.join("db/calendar/*.yml")].sort
  end

  def self.call(paths = default_paths)
    paths.sum do |path|
      data = YAML.safe_load(File.read(path), permitted_classes: [Date]) || {}
      Array(data["events"]).each { |row| upsert(row) }.size
    end
  end

  def self.upsert(row)
    event = CalendarEvent.find_or_initialize_by(
      state: row.fetch("state", "CO"), kind: row["kind"], species: row["species"].presence,
      starts_on: row["starts_on"], title: row["title"], user_id: nil
    )
    event.assign_attributes(ends_on: row["ends_on"], notes: row["notes"])
    event.save!
  end
  private_class_method :upsert
end
