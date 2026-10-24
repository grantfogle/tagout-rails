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
end
