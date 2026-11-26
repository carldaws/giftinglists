require "test_helper"

class ShopperTest < ActiveSupport::TestCase
  setup do
    @list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    @kite = users(:dan).items.create!(name: "Kite")
  end

  test "nobody else can be on your own list" do
    shopper = shopping_lists(:alices).shoppers.build(user: users(:bob))

    assert_not shopper.valid?
    assert shopper.errors.of_kind?(:base, :someone_elses_own_list)
  end

  test "leaving takes what you picked for the list back to your own list" do
    reservation = @kite.reservations.create!(user: users(:bob), shopping_list: @list)

    shopper_for(users(:bob)).leave

    assert_equal shopping_lists(:bobs), reservation.reload.shopping_list
    assert_equal [ users(:alice) ], @list.reload.people
  end

  test "leaving takes the splits you joined for the list with you" do
    split = @kite.reserve_for(users(:carol), split_with: 1)
    share = split.shares.create!(user: users(:bob), shopping_list: @list)

    shopper_for(users(:bob)).leave

    assert_equal shopping_lists(:bobs), share.reload.shopping_list
  end

  test "what everyone else picked stays on the list" do
    reservation = @kite.reservations.create!(user: users(:alice), shopping_list: @list)

    shopper_for(users(:bob)).leave

    assert_equal @list, reservation.reload.shopping_list
  end

  test "the list goes once the last person leaves" do
    shopper_for(users(:bob)).leave
    shopper_for(users(:alice)).leave

    assert_not ShoppingList.exists?(@list.id)
  end

  test "deleting your account takes you off the lists you share, and closes any left empty" do
    solo = users(:bob).start_shopping_list(name: "Just Bob")

    users(:bob).delete_account

    assert_equal [ users(:alice) ], @list.reload.people
    assert_not ShoppingList.exists?(solo.id)
  end

  test "leaving a group takes you off lists with people you're no longer in a group with" do
    list = users(:carol).start_shopping_list(name: "Carol and Alice", person_ids: [ users(:alice).id ])

    memberships(:carol_in_hollies).destroy!

    assert_equal [ users(:alice) ], list.reload.people
  end

  test "gifts on a list for someone you can no longer see go back to whoever picked them" do
    groups(:ivies).add(users(:bob))
    list = users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])
    reservation = items(:socks).reservations.create!(user: users(:carol), shopping_list: list)

    memberships(:bob_in_hollies).destroy!

    assert_equal [ users(:bob), users(:carol) ], list.reload.people.by_name
    assert_equal shopping_lists(:carols), reservation.reload.shopping_list
  end

  private
    def shopper_for(person)
      @list.shoppers.find_by!(user: person)
    end
end
