require "test_helper"

class HomeHelperTest < ActionView::TestCase
  def filters_for(path)
    Rack::Utils.parse_nested_query(URI(path).query)["filters"]
  end

  test "builds a dashboard link from species, points and residency" do
    profile = Profile.new(
      user: users(:alice), name: "Alice", residency_state: "CO",
      preference_points_attributes: [{ species: "Elk", points: "6" }]
    )
    profile.valid?
    assert_equal({ "species" => "Elk", "points" => "6", "resident" => "true" }, filters_for(dashboard_path_for(profile, "Elk")))
  end

  test "omits points when none are recorded for the species" do
    profile = Profile.new(user: users(:alice), name: "Alice", residency_state: "WY")
    profile.valid?
    assert_equal({ "species" => "Deer", "resident" => "false" }, filters_for(dashboard_path_for(profile, "Deer")))
  end

  test "works without a profile" do
    assert_equal({ "species" => "Elk" }, filters_for(dashboard_path_for(nil, "Elk")))
  end
end
