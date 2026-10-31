require "test_helper"
require "minitest/mock"
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

  def profile_with_points
    Profile.create!(user: users(:alice), name: "Alice", preference_points_attributes: [
      { species: "Elk", points: "3" }, { species: "Deer", points: "2" }
    ])
  end

  test "update destroys an existing point whose value is blanked" do
    profile = profile_with_points
    elk = profile.preference_points.find_by(species: "Elk")
    sign_in users(:alice)
    assert_difference("PreferencePoint.count", -1) do
      patch profile_url, params: { profile: { preference_points_attributes: {
        "0" => { id: elk.id, species: "Elk", points: "" }
      } } }
    end
    assert_redirected_to root_url
    assert_nil PreferencePoint.find_by(id: elk.id)
  end

  test "update destroys an id-only row (unchecked species)" do
    profile = profile_with_points
    deer = profile.preference_points.find_by(species: "Deer")
    sign_in users(:alice)
    assert_difference("PreferencePoint.count", -1) do
      patch profile_url, params: { profile: { preference_points_attributes: { "0" => { id: deer.id } } } }
    end
    assert_nil PreferencePoint.find_by(id: deer.id)
  end

  test "update still ignores a new row with blank points" do
    Profile.create!(user: users(:alice), name: "Alice")
    sign_in users(:alice)
    assert_no_difference("PreferencePoint.count") do
      patch profile_url, params: { profile: { preference_points_attributes: {
        "0" => { species: "Elk", points: "" }
      } } }
    end
    assert_redirected_to root_url
  end

  test "update applies other rows alongside a destroyed one" do
    profile = profile_with_points
    elk = profile.preference_points.find_by(species: "Elk")
    deer = profile.preference_points.find_by(species: "Deer")
    sign_in users(:alice)
    patch profile_url, params: { profile: { preference_points_attributes: {
      "0" => { id: elk.id, points: "" },
      "1" => { id: deer.id, species: "Deer", points: "7" },
      "2" => { species: "Pronghorn", points: "1" }
    } } }
    assert_nil PreferencePoint.find_by(id: elk.id)
    assert_equal 7, deer.reload.points
    assert_equal 1, profile.reload.points_for("Pronghorn")
  end

  test "create redirects to edit when a concurrent create wins the race" do
    sign_in users(:alice)
    real_new = Profile.method(:new)
    racing_new = lambda do |*args|
      real_new.call(*args).tap do |profile|
        profile.define_singleton_method(:save) { |*| raise ActiveRecord::RecordNotUnique, "duplicate" }
      end
    end
    Profile.stub(:new, racing_new) do
      post profile_url, params: valid_params
    end
    assert_redirected_to edit_profile_url
  end
end
