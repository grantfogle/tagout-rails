require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors get the marketing page" do
    get root_url
    assert_response :success
  end
end
