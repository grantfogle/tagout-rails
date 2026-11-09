require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  def build(attrs = {})
    CalendarEvent.new({ title: "Application deadline", kind: "deadline", state: "CO",
                        starts_on: Date.new(2026, 11, 10) }.merge(attrs))
  end

  test "a public event is valid" do
    assert build.valid?
  end

  test "requires title and starts_on" do
    event = build(title: nil, starts_on: nil)
    assert_not event.valid?
    assert event.errors[:title].any?
    assert event.errors[:starts_on].any?
  end

  test "rejects unknown kind, species and state" do
    assert_not build(kind: "party").valid?
    assert_not build(species: "Unicorn").valid?
    assert_not build(state: "XX").valid?
  end

  test "ends_on cannot precede starts_on" do
    assert_not build(ends_on: Date.new(2026, 11, 9)).valid?
    assert build(ends_on: Date.new(2026, 11, 10)).valid?
  end

  test "reminders need a user and public events must not have one" do
    assert_not build(kind: "reminder").valid?
    assert build(kind: "reminder", user: users(:alice)).valid?
    assert_not build(kind: "deadline", user: users(:alice)).valid?
  end

  test "blank species is stored as nil" do
    event = build(species: "")
    event.valid?
    assert_nil event.species
  end

  test "between includes events overlapping the window and excludes the rest" do
    from, to = Date.new(2026, 11, 1), Date.new(2026, 11, 30)
    before   = build(title: "before", starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 10, 31))
    lead_in  = build(title: "lead_in", kind: "season", starts_on: Date.new(2026, 10, 25), ends_on: Date.new(2026, 11, 3))
    inside   = build(title: "inside", starts_on: Date.new(2026, 11, 15))
    lead_out = build(title: "lead_out", kind: "season", starts_on: Date.new(2026, 11, 28), ends_on: Date.new(2026, 12, 5))
    last_day = build(title: "last_day", starts_on: Date.new(2026, 11, 30))
    after    = build(title: "after", starts_on: Date.new(2026, 12, 1))
    [before, lead_in, inside, lead_out, last_day, after].each(&:save!)

    titles = CalendarEvent.between(from, to).pluck(:title)
    assert_equal %w[inside last_day lead_in lead_out], titles.sort
  end

  test "visible_to returns public events and the user's own reminders" do
    public_event = build(title: "public"); public_event.save!
    mine = build(title: "mine", kind: "reminder", user: users(:alice)); mine.save!
    theirs = build(title: "theirs", kind: "reminder", user: users(:bob)); theirs.save!

    assert_equal %w[mine public], CalendarEvent.visible_to(users(:alice)).pluck(:title).sort
  end

  test "for_species keeps all-species events and the listed species" do
    build(title: "all").save!
    build(title: "elk", species: "Elk").save!
    build(title: "deer", species: "Deer").save!

    assert_equal %w[all elk], CalendarEvent.for_species(["Elk"]).pluck(:title).sort
    assert_equal %w[all deer elk], CalendarEvent.for_species([]).pluck(:title).sort
    assert_equal %w[all deer elk], CalendarEvent.for_species(nil).pluck(:title).sort
  end

  test "chronological orders by starts_on" do
    build(title: "later", starts_on: Date.new(2026, 12, 1)).save!
    build(title: "sooner", starts_on: Date.new(2026, 11, 1)).save!
    assert_equal %w[sooner later], CalendarEvent.chronological.pluck(:title)
  end
end
