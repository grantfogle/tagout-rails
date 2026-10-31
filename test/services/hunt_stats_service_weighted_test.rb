require "test_helper"

class HuntStatsServiceWeightedTest < ActiveSupport::TestCase
  CODE = "SMS99O1R".freeze

  setup do
    WeightedStat.where(hunt_code: CODE).delete_all
    # Resident pool: 20 under 3 points, then 10 at weight 0 and 10 at weight 1 (6 licenses).
    [
      { preference_points: 1, weighted_points: 0, applicants: 20, success: 0 },
      { preference_points: 3, weighted_points: 0, applicants: 10, success: 2 },
      { preference_points: 3, weighted_points: 1, applicants: 10, success: 4 }
    ].each do |attrs|
      WeightedStat.create!({ hunt_code: CODE, resident: true, adult: true }.merge(attrs))
    end
    WeightedStat.create!(hunt_code: CODE, resident: false, adult: true,
                         preference_points: 3, weighted_points: 2, applicants: 5, success: 1)
  end

  def result
    HuntStatsService.new.weighted_results([CODE])[CODE]
  end

  test "projected odds come from the eligible pool and the licenses awarded" do
    levels = result[:resident][:levels]
    assert_in_delta 20.0, levels[0][:projected], 0.1 # cutoff 0.2 * factor 1
    assert_in_delta 40.0, levels[1][:projected], 0.1 # cutoff 0.2 * factor 2
  end

  test "actual results are reported per level" do
    level = result[:resident][:levels][1]
    assert_equal 10, level[:applicants]
    assert_equal 4, level[:success]
    assert_in_delta 40.0, level[:actual], 0.01
  end

  test "applicants under 3 preference points are summed into one actuals-only cell" do
    under = result[:resident][:under_three]
    assert_equal 20, under[:applicants]
    assert_equal 0, under[:success]
    assert_nil under[:projected]
  end

  test "residents and nonresidents are separate pools" do
    nonres = result[:nonresident][:levels]
    assert_equal [2], nonres.keys
    assert_in_delta 20.0, nonres[2][:projected], 0.1 # 1 license, 5 applicants
  end

  test "levels under ten applicants are flagged as small samples" do
    assert result[:nonresident][:levels][2][:sparse]
    assert_not result[:resident][:levels][0][:sparse]
  end

  test "codes without weighted rows are omitted" do
    assert_equal({}, HuntStatsService.new.weighted_results(["NOPE"]))
  end

  test "max_weighted_points reports the widest level for a species" do
    HuntStat.create!(hunt_code: CODE, state: "CO", species: "Moose", sex: "E", unit: "999", season: "O1",
                     hunt_method: "Rifle", resident: true, adult: true, draw_type: "pref", value: 3, applicants: 1, success: 0)
    assert_operator HuntStatsService.new.max_weighted_points("Moose"), :>=, 2
  end
end
