require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    {
      profile: {
        name: "Alice",
        residency_state: "CO",
        favorite_species: ["", "Elk"],
        states_of_interest: ["", "CO", "WY"],
        preferred_methods: ["", "Rifle"],
        notifications_enabled: "1",
        preference_points_attributes: {
          "0" => { species: "Elk", points: "6" },
          "1" => { species: "Deer", points: "" }
        }
      }
    }
  end

  test "signed-out users are sent to sign in" do
    get new_profile_url
    assert_redirected_to new_user_session_url
    post profile_url, params: valid_params
    assert_redirected_to new_user_session_url
  end

  test "new renders the form with a skip link" do
    sign_in users(:alice)
    get new_profile_url
    assert_response :success
    assert_select "form[action=?]", profile_path
    assert_select "a[href=?]", root_path, text: "Skip for now"
    assert_select "input[type=number][name*=points]", count: HuntStat::SPECIES_OPTIONS.size
  end

  test "new redirects to edit when a profile already exists" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    get new_profile_url
    assert_redirected_to edit_profile_url
  end

  test "create saves the profile, derived residency and points" do
    sign_in users(:alice)
    assert_difference("Profile.count", 1) { post profile_url, params: valid_params }
    assert_redirected_to root_url

    profile = users(:alice).reload.profile
    assert_equal "Alice", profile.name
    assert_equal true, profile.resident
    assert_equal ["Elk"], profile.favorite_species
    assert_equal %w[CO WY], profile.states_of_interest
    assert_equal ["Rifle"], profile.preferred_methods
    assert profile.notifications_enabled
    assert_equal [["Elk", 6]], profile.preference_points.map { |p| [p.species, p.points] }
  end

  test "create with a blank name re-renders with 422" do
    sign_in users(:alice)
    assert_no_difference("Profile.count") do
      post profile_url, params: { profile: valid_params[:profile].merge(name: "") }
    end
    assert_response :unprocessable_entity
  end

  test "edit redirects to new when no profile exists" do
    sign_in users(:alice)
    get edit_profile_url
    assert_redirected_to new_profile_url
  end

  test "edit renders without a skip link" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    get edit_profile_url
    assert_response :success
    assert_select "a", text: "Skip for now", count: 0
  end

  test "update changes attributes and existing points" do
    profile = Profile.create!(user: users(:alice), name: "Alice", preference_points_attributes: [{ species: "Elk", points: "3" }])
    point = profile.preference_points.first
    sign_in users(:alice)

    patch profile_url, params: { profile: {
      name: "Alice H.",
      preference_points_attributes: { "0" => { id: point.id, species: "Elk", points: "5" } }
    } }

    assert_redirected_to root_url
    assert_equal "Alice H.", profile.reload.name
    assert_equal 5, point.reload.points
  end

  test "update with invalid data re-renders with 422" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    patch profile_url, params: { profile: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "users cannot edit another user's points" do
    other = Profile.create!(user: users(:bob), name: "Bob", preference_points_attributes: [{ species: "Elk", points: "9" }])
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)

    assert_raises(ActiveRecord::RecordNotFound) do
      patch profile_url, params: { profile: {
        preference_points_attributes: { "0" => { id: other.preference_points.first.id, points: "0" } }
      } }
    end

    assert_equal 9, other.preference_points.first.reload.points
  end
end
