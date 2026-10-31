require "test_helper"

class CalendarServiceTest < ActiveSupport::TestCase
  setup { travel_to Time.zone.local(2026, 10, 31, 12) }
  teardown { travel_back }

  def event(title, starts_on, attrs = {})
    CalendarEvent.create!({ title: title, kind: "deadline", state: "CO", starts_on: starts_on }.merge(attrs))
  end

  def reminder(title, starts_on, user)
    CalendarEvent.create!(title: title, kind: "reminder", state: "CO", starts_on: starts_on, user: user)
  end

  test "upcoming covers today through 30 days, in order, including seasons already underway" do
    event("past", Date.new(2026, 10, 1))
    event("beyond", Date.new(2026, 12, 15))
    event("soon", Date.new(2026, 11, 15))
    event("underway", Date.new(2026, 10, 20), kind: "season", ends_on: Date.new(2026, 11, 5))

    titles = CalendarService.new(users(:alice)).upcoming.map(&:title)
    assert_equal %w[underway soon], titles
  end

  test "upcoming hides other users' reminders" do
    reminder("mine", Date.new(2026, 11, 2), users(:alice))
    reminder("theirs", Date.new(2026, 11, 2), users(:bob))

    assert_equal %w[mine], CalendarService.new(users(:alice)).upcoming.map(&:title)
  end

  test "year returns 12 month buckets starting at the current month" do
    event("underway", Date.new(2026, 10, 20), kind: "season", ends_on: Date.new(2026, 11, 5))
    event("spring", Date.new(2027, 3, 3))
    event("too far", Date.new(2027, 10, 31))

    months = CalendarService.new(users(:alice)).year
    assert_equal 12, months.size
    assert_equal Date.new(2026, 10, 1), months.keys.first
    assert_equal Date.new(2027, 9, 1), months.keys.last
    assert_equal %w[underway], months[Date.new(2026, 10, 1)].map(&:title)
    assert_equal %w[spring], months[Date.new(2027, 3, 1)].map(&:title)
    assert_equal [], months[Date.new(2027, 1, 1)]
    assert_not months.values.flatten.map(&:title).include?("too far")
  end

  test "species falls back to the profile's favorites; explicit species wins" do
    Profile.create!(user: users(:bob), name: "Bob", favorite_species: %w[Elk])
    event("general", Date.new(2026, 11, 2))
    event("elk", Date.new(2026, 11, 3), species: "Elk")
    event("deer", Date.new(2026, 11, 4), species: "Deer")

    assert_equal %w[general elk], CalendarService.new(users(:bob)).upcoming.map(&:title)
    assert_equal %w[general elk deer], CalendarService.new(users(:alice)).upcoming.map(&:title)

    deer_year = CalendarService.new(users(:bob)).year(species: "Deer").values.flatten.map(&:title)
    assert_equal %w[general deer], deer_year
  end

  test "mine_only keeps just the user's reminders" do
    event("public", Date.new(2026, 11, 2))
    reminder("mine", Date.new(2026, 11, 3), users(:alice))

    titles = CalendarService.new(users(:alice)).year(mine_only: true).values.flatten.map(&:title)
    assert_equal %w[mine], titles
  end
end
