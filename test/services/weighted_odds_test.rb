require "test_helper"

class WeightedOddsTest < ActiveSupport::TestCase
  def odds(levels, awarded)
    WeightedOdds.new(levels, awarded).odds
  end

  test "everyone draws when licenses cover all applicants" do
    assert_equal({ 0 => 1.0, 5 => 1.0 }, odds({ 0 => 4, 5 => 6 }, 10))
    assert_equal({ 0 => 1.0 }, odds({ 0 => 4 }, 12))
  end

  test "nobody draws when no licenses were awarded" do
    assert_equal({ 0 => 0.0, 3 => 0.0 }, odds({ 0 => 4, 3 => 6 }, 0))
  end

  test "a single level has odds of licenses over applicants whatever its weight" do
    assert_in_delta 0.5, odds({ 0 => 10 }, 5)[0], 1e-9
    assert_in_delta 0.5, odds({ 3 => 10 }, 5)[3], 1e-9
  end

  test "odds scale with weighted points plus one" do
    # 10 applicants at weight 0 (factor 1), 10 at weight 1 (factor 2), 6 licenses:
    # cutoff t = 6 / (10*1 + 10*2) = 0.2, so odds are 0.2 and 0.4.
    result = odds({ 0 => 10, 1 => 10 }, 6)
    assert_in_delta 0.2, result[0], 1e-9
    assert_in_delta 0.4, result[1], 1e-9
  end

  test "high weights saturate at 100% and the rest share what is left" do
    # Weight 9 (factor 10) saturates once the cutoff passes 0.1. With 15 licenses all
    # 10 of those applicants draw and the remaining 5 licenses go to the 10 at weight 0.
    result = odds({ 0 => 10, 9 => 10 }, 15)
    assert_in_delta 0.5, result[0], 1e-9
    assert_in_delta 1.0, result[9], 1e-9
  end

  test "expected winners across levels equal the licenses awarded" do
    levels = { 0 => 40, 1 => 25, 4 => 12, 10 => 6, 25 => 2 }
    result = odds(levels, 20)
    assert_in_delta 20.0, levels.sum { |w, n| n * result[w] }, 1e-6
  end

  test "levels with no applicants are ignored" do
    assert_equal({ 0 => 0.5 }, odds({ 0 => 10, 2 => 0 }, 5).slice(0))
  end

  test "empty pool returns no odds" do
    assert_equal({}, odds({}, 5))
  end
end
