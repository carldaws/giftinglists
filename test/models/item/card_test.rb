require "test_helper"

class Item::CardTest < ActiveSupport::TestCase
  setup do
    @kite = users(:dan).items.create!(name: "Kite", quantity: 2)
  end

  def card_for(viewer, **)
    Wishlist.new(users(:dan), viewer:, **).cards.find { it.item == @kite }
  end

  test "an item nobody has picked can be reserved or split" do
    card = card_for(users(:carol))

    assert card.reservable?
    assert card.splittable?
    assert_nil card.my_reservation
  end

  test "your own reservation is yours" do
    reservation = @kite.reserve_for(users(:carol))

    assert_equal reservation, card_for(users(:carol)).my_reservation
  end

  test "someone else's waiting split can be joined, but not once you're in it" do
    split = @kite.reserve_for(users(:alice), split_with: 1)

    assert_equal [ split ], card_for(users(:carol)).joinable_splits

    split.join(users(:carol))
    card = card_for(users(:carol))

    assert_empty card.joinable_splits
    assert_equal split, card.joined_split
  end

  test "people already getting it don't count towards how many you can split with" do
    assert_equal 2, card_for(users(:carol)).split_limit

    @kite.reserve_for(users(:bob))

    assert_equal 1, card_for(users(:carol)).split_limit
  end

  test "you choose from your lists that can have gifts for them" do
    with_bob = users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])

    assert_equal [ shopping_lists(:carols), with_bob ], card_for(users(:carol)).shopping_lists_to_reserve_on
    assert_empty card_for(users(:alice)).shopping_lists_to_reserve_on
  end

  test "a list with someone on it who's already in a split can't take it again" do
    users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])
    @kite.reserve_for(users(:alice), split_with: 2).join(users(:bob))

    card = card_for(users(:carol))

    assert_equal [ shopping_lists(:carols) ], card.shopping_lists_to_join_on
    assert_equal [ shopping_lists(:carols) ], card.shopping_lists_to_reserve_on
  end

  test "a split can only go on lists that leave someone to split with" do
    with_bob = users(:carol).start_shopping_list(name: "Carol and Bob", person_ids: [ users(:bob).id ])
    @kite.reserve_for(users(:alice))

    card = card_for(users(:carol))

    assert_equal [ shopping_lists(:carols), with_bob ], card.shopping_lists_to_reserve_on
    assert_equal [ shopping_lists(:carols) ], card.shopping_lists_to_split_on
    assert_equal 1, card.split_limit
  end

  test "it can't be reserved once every one is taken" do
    @kite.reserve_for(users(:alice))
    @kite.reserve_for(users(:bob))

    assert_not card_for(users(:carol)).reservable?
  end

  test "choosing an occasion needs your own reservation and an occasion to choose" do
    assert_not card_for(users(:carol)).choosing_occasion?

    @kite.reserve_for(users(:carol))
    card = card_for(users(:carol))

    assert card.choosing_occasion?
    assert_not card.occasion_shown_for?(card.my_reservation)
  end

  test "guardians with surprises hidden see no reservations but can still edit" do
    @kite.reserve_for(users(:carol))
    card = card_for(users(:alice))

    assert_not card.reservations_shown?
    assert_empty card.reservations
    assert card.actions?
  end
end
