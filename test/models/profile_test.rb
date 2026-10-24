require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  def build_profile(**attrs)
    Profile.new({ user: users(:alice), name: "Alice" }.merge(attrs))
  end

  test "valid with just a name" do
    assert build_profile.valid?
  end

  test "requires a name" do
    profile = build_profile(name: "")
    assert_not profile.valid?
    assert_includes profile.errors[:name], "can't be blank"
  end

  test "one profile per user" do
    build_profile.save!
    assert_not build_profile.valid?
  end

  test "resident is derived from residency state" do
    assert_equal true, build_profile(residency_state: "CO").tap(&:valid?).resident
    assert_equal false, build_profile(residency_state: "WY").tap(&:valid?).resident
    assert_nil build_profile(residency_state: "").tap(&:valid?).resident
  end

  test "rejects unknown residency state" do
    assert_not build_profile(residency_state: "ZZ").valid?
  end

  test "rejects unknown species, methods and states of interest" do
    assert_not build_profile(favorite_species: ["Moose"]).valid?
    assert_not build_profile(preferred_methods: ["Crossbow"]).valid?
    assert_not build_profile(states_of_interest: ["ZZ"]).valid?
  end

  test "accepts known species, methods and states of interest" do
    profile = build_profile(favorite_species: %w[Elk Deer], preferred_methods: ["Rifle"], states_of_interest: %w[CO WY])
    assert profile.valid?
  end

  test "strips blank and duplicate array entries" do
    profile = build_profile(favorite_species: ["", "Elk", "Elk"])
    profile.valid?
    assert_equal ["Elk"], profile.favorite_species
  end

  test "nested points: blank points are rejected, filled ones saved" do
    profile = build_profile(
      favorite_species: %w[Elk Deer],
      preference_points_attributes: [
        { species: "Elk", points: "6" },
        { species: "Deer", points: "" }
      ]
    )
    profile.save!
    assert_equal [["Elk", 6]], profile.preference_points.map { |p| [p.species, p.points] }
  end

  test "points_for returns points for a species or nil" do
    profile = build_profile(preference_points_attributes: [{ species: "Elk", points: "4" }])
    assert_equal 4, profile.points_for("Elk")
    assert_nil profile.points_for("Deer")
  end

  test "residency_label" do
    assert_equal "Colorado resident", build_profile(residency_state: "CO").residency_label
    assert_equal "Wyoming resident", build_profile(residency_state: "WY").residency_label
    assert_nil build_profile.residency_label
  end
end
