require "test_helper"

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  test "renders for signed-out visitors with current and future sections" do
    get features_url
    assert_response :success
    assert_select "h2", text: "Current features"
    assert_select "h2", text: "Coming soon"
  end

  test "renders for signed-in users" do
    sign_in users(:alice)
    get features_url
    assert_response :success
  end
end
