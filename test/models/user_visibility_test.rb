require "test_helper"

class UserVisibilityTest < ActiveSupport::TestCase
  test "you see yourself, the people in your groups, and your dependants" do
    visible = User.visible_to(users(:alice))

    assert_includes visible, users(:alice)
    assert_includes visible, users(:bob)
    assert_includes visible, users(:dan)
    assert_not_includes visible, users(:erin)
  end

  test "someone in two groups sees the people in both" do
    visible = User.visible_to(users(:carol))

    assert_includes visible, users(:alice)
    assert_includes visible, users(:erin)
  end

  test "someone can be seen by the people in their groups, themselves and whoever looks after them" do
    memberships(:dan_in_hollies).destroy!

    assert_equal [ users(:alice), users(:bob), users(:dan) ], User.who_can_see(users(:dan)).by_name
    assert_equal [ users(:carol), users(:erin) ], User.who_can_see(users(:erin)).by_name
  end

  test "guardians see their dependants even outside shared groups" do
    memberships(:dan_in_hollies).destroy!

    assert users(:dan).visible_to?(users(:alice))
  end
end
