require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors get the marketing page and public nav" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", new_user_registration_path
    assert_select "a[href=?]", features_path
    assert_select "a[href=?]", dashboard_path, count: 0
  end

  test "signed-in user without a profile sees the finish-profile banner" do
    sign_in users(:alice)
    get root_url
    assert_response :success
    assert_select ".banner", text: /Finish your profile/
    assert_select "a[href=?]", new_profile_path
  end

  test "signed-in user with a profile sees a personal home screen" do
    user = users(:bob)
    Profile.create!(
      user: user, name: "Bob Hunter", residency_state: "CO", favorite_species: %w[Elk],
      preference_points_attributes: [{ species: "Elk", points: "6" }]
    )
    sign_in user
    get root_url
    assert_response :success
    assert_select "h1", text: /Welcome back, Bob Hunter/
    assert_select ".banner", count: 0
    assert_select "a[href=?]", dashboard_path(filters: { species: "Elk", points: 6, resident: true })
    assert_select "a[href=?]", edit_profile_path
  end

  test "signed-in nav links to home, dashboard and features" do
    sign_in users(:alice)
    get root_url
    assert_select "nav.navbar a[href=?]", root_path
    assert_select "nav.navbar a[href=?]", dashboard_path
    assert_select "nav.navbar a[href=?]", features_path
  end

  test "signed-in home lists events from the next 30 days only" do
    travel_to Time.zone.local(2026, 10, 31, 12) do
      CalendarEvent.create!(title: "Soon deadline", kind: "deadline", starts_on: Date.new(2026, 11, 10))
      CalendarEvent.create!(title: "Far away", kind: "deadline", starts_on: Date.new(2027, 3, 1))
      sign_in users(:alice)
      get root_url
      assert_select ".calendar-event__title", text: "Soon deadline"
      assert_select ".calendar-event__title", text: "Far away", count: 0
      assert_select "a[href=?]", calendar_path
    end
  end

  test "signed-in home shows an empty state when nothing is coming up" do
    sign_in users(:alice)
    get root_url
    assert_select ".home__empty", text: /Nothing in the next 30 days/
  end

  test "signed-out visitors do not see the calendar section" do
    get root_url
    assert_select ".calendar-event", count: 0
    assert_select "a[href=?]", calendar_path, count: 0
  end
end
