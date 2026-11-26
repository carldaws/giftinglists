require "test_helper"

class ShoppingListTest < ActiveSupport::TestCase
  test "starting a list puts you on it with the people you choose" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    assert list.persisted?
    assert_equal [ users(:alice), users(:bob) ], list.people.by_name
  end

  test "you can only start a list with people from your groups who have their own account" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:erin).id, users(:dan).id ])

    assert_equal [ users(:alice) ], list.people
  end

  test "everyone on a new list needs to be in a group with everyone else on it" do
    list = users(:carol).start_shopping_list(name: "Mixed", person_ids: [ users(:alice).id, users(:erin).id ])

    assert_not list.persisted?
    assert list.errors.of_kind?(:base, :strangers)
  end

  test "a list you share needs a name" do
    assert_not users(:alice).start_shopping_list(name: " ").persisted?
  end

  test "nobody can join a list with a gift on it for them" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    items(:books).reservations.create!(user: users(:alice), shopping_list: list)

    shopper = list.shoppers.build(user: users(:carol))

    assert_not shopper.valid?
    assert shopper.errors.of_kind?(:base, :cannot_join)
  end

  test "nobody can join a list with a gift on it for someone outside their groups" do
    list = users(:carol).start_shopping_list(name: "Camping")
    items(:tent).reservations.create!(user: users(:carol), shopping_list: list)

    assert_not list.shoppers.build(user: users(:alice)).valid?
    assert_equal [ users(:carol) ], list.people_who_can_join.where(id: [ users(:alice), users(:bob), users(:carol) ]).to_a
  end

  test "nobody can join a list that would put them in the same split twice" do
    kite = users(:dan).items.create!(name: "Kite")
    split = kite.reserve_for(users(:alice), split_with: 2)
    split.join(users(:bob))
    solo = users(:carol).start_shopping_list(name: "Solo")
    split.join(users(:carol), shopping_list: solo)

    assert_not solo.shoppers.build(user: users(:bob)).valid?
  end

  test "gifts that have been given don't stop anyone joining" do
    list = users(:carol).start_shopping_list(name: "Camping")
    trip = groups(:ivies).occasions.create!(name: "Camping trip", date: 1.week.from_now.to_date)
    items(:tent).reservations.create!(user: users(:carol), shopping_list: list, occasion: trip, bought_at: Time.current)

    travel_to trip.date + 1.day do
      assert list.shoppers.build(user: users(:alice)).valid?
    end
  end

  test "nobody can join a list with someone on it they aren't in a group with" do
    list = users(:carol).start_shopping_list(name: "Us", person_ids: [ users(:alice).id ])

    assert_not list.shoppers.build(user: users(:erin)).valid?
    assert_equal [ users(:bob) ], list.people_addable_by(users(:carol)).to_a
  end

  test "gifts for someone can go on lists they aren't on, where everyone can see them" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    camping = users(:carol).start_shopping_list(name: "Camping", person_ids: [ users(:erin).id ])

    assert_includes ShoppingList.for_gifts_to(users(:carol)), us
    assert_not_includes ShoppingList.for_gifts_to(users(:alice)), us
    assert_not_includes ShoppingList.for_gifts_to(users(:alice)), camping
    assert_includes ShoppingList.for_gifts_to(users(:dan)), shopping_lists(:carols)
  end

  test "you can add people from your groups who could join and aren't on it already" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    assert_equal [ users(:carol) ], list.people_addable_by(users(:alice)).to_a
  end
end
