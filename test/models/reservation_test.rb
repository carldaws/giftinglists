require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  test "the owner never sees reservations on their own items" do
    assert_not_includes Reservation.visible_to(users(:alice)), reservations(:bob_reserved_scarf)
  end

  test "the owner sees no reservations however many groups they're in" do
    groups(:ivies).add(users(:alice))

    assert_not_includes Reservation.visible_to(users(:alice)), reservations(:bob_reserved_scarf)
  end

  test "everyone else in a group with the owner sees reservations" do
    assert_includes Reservation.visible_to(users(:carol)), reservations(:bob_reserved_scarf)
  end

  test "people who share no group with the owner don't see their reservations" do
    assert_not_includes Reservation.visible_to(users(:erin)), reservations(:bob_reserved_scarf)
  end

  test "guardians see reservations on their dependant's items" do
    assert_includes Reservation.visible_to(users(:alice)), reservations(:carol_bought_lego)
  end

  test "the owner can't reserve their own item" do
    reservation = items(:socks).reservations.build(user: users(:alice))

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:user, :owns_the_list)
  end

  test "people who can't see an item can't reserve it" do
    reservation = items(:socks).reservations.build(user: users(:erin))

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:user, :cannot_see_the_list)
  end

  test "guardians can reserve an item for their dependant" do
    kite = users(:dan).items.create!(name: "Kite")

    assert kite.reservations.build(user: users(:alice)).valid?
  end

  test "nobody can reserve an item once its quantity is taken" do
    reservation = items(:scarf).reservations.build(user: users(:carol))

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:item, :fully_reserved)
  end

  test "several people can each reserve one of a quantity" do
    items(:socks).reservations.create!(user: users(:bob))

    assert items(:socks).reservations.create!(user: users(:carol)).persisted?
  end

  test "one reservation per person per item" do
    items(:socks).reservations.create!(user: users(:bob))

    assert_raises(ActiveRecord::RecordNotUnique) do
      items(:socks).reservations.create!(user: users(:bob))
    end
  end

  test "reserving picks the soonest occasion for that person" do
    reservation = items(:socks).reserve_for(users(:carol))

    assert_equal occasions(:christmas), reservation.occasion
  end

  test "a birthday that comes sooner is picked instead" do
    users(:alice).update!(birthday_month: 1.week.from_now.month, birthday_day: 1.week.from_now.day)

    reservation = items(:socks).reserve_for(users(:carol))

    assert reservation.occasion.birthday?
  end

  test "an occasion must be one for gifts to that person, in a group you share" do
    other_groups_occasion = groups(:ivies).occasions.create!(name: "Ivies picnic", date: 1.month.from_now.to_date)

    reservation = items(:socks).reservations.build(user: users(:carol), occasion: other_groups_occasion)

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:occasion, :not_for_this_person)
  end

  test "a bought gift counts as given once its occasion has passed" do
    reservation = items(:socks).reserve_for(users(:carol))
    reservation.buy
    assert_not reservation.given?

    travel_to occasions(:christmas).date + 1.day do
      assert reservation.reload.given?
      assert_not items(:socks).given_with?([ reservation ])
    end
  end

  test "what you reserve goes on your own shopping list" do
    assert_equal shopping_lists(:carols), items(:socks).reserve_for(users(:carol)).shopping_list
  end

  test "you can put what you reserve on a list you share" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    assert_equal us, items(:books).reserve_for(users(:alice), shopping_list: us).shopping_list
  end

  test "you can't put what you reserve on a list you aren't on" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    reservation = items(:books).reserve_for(users(:erin), shopping_list: us)

    assert reservation.errors.of_kind?(:base, :wrong_shopping_list)
  end

  test "a gift can't go on a list the person it's for is on" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    reservation = items(:socks).reserve_for(users(:bob), shopping_list: us)

    assert reservation.errors.of_kind?(:base, :wrong_shopping_list)
  end

  test "a gift can't go on a list with someone who can't see the person it's for" do
    camping = users(:carol).start_shopping_list(name: "Camping", person_ids: [ users(:erin).id ])

    reservation = items(:socks).reserve_for(users(:carol), shopping_list: camping)

    assert reservation.errors.of_kind?(:base, :wrong_shopping_list)
  end

  test "a gift can't go on a list with someone on it who's splitting the same thing" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    kite = users(:dan).items.create!(name: "Kite", quantity: 2)
    kite.reserve_for(users(:carol), split_with: 1).join(users(:bob))

    assert kite.reserve_for(users(:alice), shopping_list: us).errors.of_kind?(:base, :shopping_list_already_getting_it)
    assert kite.reserve_for(users(:alice)).persisted?
  end

  test "a gift can't go on a list with someone on it who started a split for the same thing" do
    with_bob = users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])
    kite = users(:dan).items.create!(name: "Kite", quantity: 2)
    kite.reserve_for(users(:bob), split_with: 1)

    assert kite.reserve_for(users(:carol), shopping_list: with_bob).errors.of_kind?(:base, :shopping_list_already_getting_it)
  end

  test "a split can't go on a list with someone on it who's already getting the same thing" do
    with_bob = users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])
    kite = users(:dan).items.create!(name: "Kite", quantity: 2)
    kite.reserve_for(users(:bob))

    assert kite.reserve_for(users(:carol), shopping_list: with_bob, split_with: 1).errors.of_kind?(:base, :shopping_list_already_getting_it)
  end

  test "buying" do
    reservations(:bob_reserved_scarf).buy
    assert reservations(:bob_reserved_scarf).bought?

    reservations(:bob_reserved_scarf).unbuy
    assert_not reservations(:bob_reserved_scarf).bought?
  end
end
