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
end
