require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects signed-out users to sign in" do
    get dashboard_url
    assert_redirected_to new_user_session_url
  end

  test "renders for signed-in users" do
    sign_in users(:alice)
    get dashboard_url
    assert_response :success
  end

  test "a weighted species shows weighted columns with projected and actual odds" do
    create_weighted_hunt
    sign_in users(:alice)
    get dashboard_url, params: { filters: { species: "Moose" } }

    assert_response :success
    assert_select ".weighted-note", text: /Weighted draw odds/
    assert_select "th.point-header--under", text: "Under 3 pts"
    assert_select "td.weighted-cell .draw-cell__odds--projected"
    assert_select "td.weighted-cell .draw-cell__actual", text: /actual\s+4\/10/
  end

  test "all species flags weighted hunts without switching layout" do
    create_weighted_hunt
    sign_in users(:alice)
    get dashboard_url

    assert_response :success
    assert_select ".weighted-badge"
    assert_select ".weighted-hint"
    assert_select "th.point-header--under", count: 0
  end

  test "a regular species has no weighted note or badges" do
    sign_in users(:alice)
    get dashboard_url, params: { filters: { species: "Elk" } }

    assert_response :success
    assert_select ".weighted-note", count: 0
    assert_select ".weighted-badge", count: 0
  end

  private

  def create_weighted_hunt
    HuntStat.create!(hunt_code: "MM999O1R", state: "CO", species: "Moose", sex: "M", unit: "999", season: "O1",
                     hunt_method: "Rifle", resident: true, adult: true, draw_type: "pref", value: 3, applicants: 20, success: 6)
    WeightedStat.create!(hunt_code: "MM999O1R", resident: true, adult: true, preference_points: 3,
                         weighted_points: 0, applicants: 10, success: 2)
    WeightedStat.create!(hunt_code: "MM999O1R", resident: true, adult: true, preference_points: 3,
                         weighted_points: 1, applicants: 10, success: 4)
  end
end
