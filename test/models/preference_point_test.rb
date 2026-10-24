require "test_helper"

class PreferencePointTest < ActiveSupport::TestCase
  setup do
    @profile = Profile.create!(user: users(:alice), name: "Alice")
  end

  test "valid point" do
    assert @profile.preference_points.build(species: "Elk", points: 0).valid?
    assert @profile.preference_points.build(species: "Deer", points: 99).valid?
  end

  test "points must be an integer between 0 and 99" do
    assert_not @profile.preference_points.build(species: "Elk", points: -1).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: 100).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: 1.5).valid?
    assert_not @profile.preference_points.build(species: "Elk", points: nil).valid?
  end

  test "species must be a known species" do
    assert_not @profile.preference_points.build(species: "Moose", points: 1).valid?
  end

  test "one row per species per profile" do
    @profile.preference_points.create!(species: "Elk", points: 1)
    assert_not @profile.preference_points.build(species: "Elk", points: 2).valid?
  end
end
