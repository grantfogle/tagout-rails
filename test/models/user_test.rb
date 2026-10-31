require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "has one profile, destroyed with the user" do
    user = users(:alice)
    Profile.create!(user: user, name: "Alice")
    assert_difference("Profile.count", -1) { user.destroy }
  end
end
