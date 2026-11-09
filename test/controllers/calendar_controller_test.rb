require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.zone.local(2026, 10, 31, 12) }
  teardown { travel_back }

  def event(title, starts_on, attrs = {})
    CalendarEvent.create!({ title: title, kind: "deadline", state: "CO", starts_on: starts_on }.merge(attrs))
  end

  test "requires login" do
    get calendar_url
    assert_redirected_to new_user_session_path
  end

  test "shows twelve month sections with events" do
    event("Spring deadline", Date.new(2027, 4, 6))
    sign_in users(:alice)
    get calendar_url
    assert_response :success
    assert_select ".calendar__month", count: 12
    assert_select ".calendar__month-title", text: "April 2027"
    assert_select ".calendar-event__title", text: "Spring deadline"
  end

  test "does not show another user's reminders" do
    CalendarEvent.create!(title: "Bob only", kind: "reminder", starts_on: Date.new(2026, 11, 5), user: users(:bob))
    sign_in users(:alice)
    get calendar_url
    assert_select ".calendar-event__title", text: "Bob only", count: 0
  end

  test "species filter narrows the list" do
    event("Elk thing", Date.new(2026, 11, 5), species: "Elk")
    event("Deer thing", Date.new(2026, 11, 6), species: "Deer")
    sign_in users(:alice)
    get calendar_url(species: "Deer")
    assert_select ".calendar-event__title", text: "Deer thing"
    assert_select ".calendar-event__title", text: "Elk thing", count: 0
  end

  test "an unknown species param is ignored" do
    event("Elk thing", Date.new(2026, 11, 5), species: "Elk")
    sign_in users(:alice)
    get calendar_url(species: "Unicorn")
    assert_response :success
    assert_select ".calendar-event__title", text: "Elk thing"
  end

  test "mine only shows just the user's reminders" do
    event("Public", Date.new(2026, 11, 5))
    CalendarEvent.create!(title: "Mine", kind: "reminder", starts_on: Date.new(2026, 11, 6), user: users(:alice))
    sign_in users(:alice)
    get calendar_url(mine: "1")
    assert_select ".calendar-event__title", text: "Mine"
    assert_select ".calendar-event__title", text: "Public", count: 0
  end
end
