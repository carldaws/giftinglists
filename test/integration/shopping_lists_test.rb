require "test_helper"

class ShoppingListsTest < ActionDispatch::IntegrationTest
  test "your account menu links to your shopping lists" do
    sign_in_as users(:alice)

    get root_path

    assert_select ".menu a[href=?]", shopping_lists_path
  end

  test "making a list with someone from your groups" do
    sign_in_as users(:alice)

    get new_shopping_list_path
    assert_select "input[name='shopping_list[person_ids][]'][value=?]", users(:bob).id.to_s
    assert_select "input[name='shopping_list[person_ids][]'][value=?]", users(:erin).id.to_s, count: 0

    post shopping_lists_path, params: { shopping_list: { name: "Us", person_ids: [ "", users(:bob).id ] } }

    list = ShoppingList.find_by!(name: "Us")
    assert_redirected_to shopping_lists_path
    assert_equal [ users(:alice), users(:bob) ], list.people.by_name

    follow_redirect!
    assert_select "##{dom_id(list)} h2", text: "Us"
    assert_select "##{dom_id(list)} .row-title", text: users(:bob).name
  end

  test "a list needs a name" do
    sign_in_as users(:alice)

    post shopping_lists_path, params: { shopping_list: { name: "" } }

    assert_response :unprocessable_content
  end

  test "everyone on a list sees it, and nobody else does" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])

    sign_in_as users(:bob)
    get shopping_lists_path
    assert_select "##{dom_id(list)}"

    delete session_path
    sign_in_as users(:carol)
    get shopping_lists_path
    assert_select "##{dom_id(list)}", count: 0
    assert_select ".empty", text: I18n.t("shopping_lists.index.empty")

    get edit_shopping_list_path(list)
    assert_response :not_found
  end

  test "people who aren't on a list can't change it" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    sign_in_as users(:carol)

    patch shopping_list_path(list), params: { shopping_list: { name: "Ours now" } }
    assert_response :not_found

    post shopping_list_shoppers_path(list), params: { shopper: { user_id: users(:carol).id } }
    assert_response :not_found

    delete shopping_list_shopper_path(list, list.shoppers.find_by!(user: users(:bob)))
    assert_response :not_found

    assert_equal [ users(:alice), users(:bob) ], list.reload.people.by_name
  end

  test "your own list isn't one you manage here" do
    sign_in_as users(:alice)

    get edit_shopping_list_path(shopping_lists(:alices))

    assert_response :not_found
  end

  test "adding someone to a list" do
    list = users(:alice).start_shopping_list(name: "Us")
    sign_in_as users(:alice)

    get shopping_lists_path
    assert_select "##{dom_id(list)} select option[value=?]", users(:bob).id.to_s

    post shopping_list_shoppers_path(list), params: { shopper: { user_id: users(:bob).id } }

    assert_redirected_to shopping_lists_path
    assert list.reload.shopper?(users(:bob))
  end

  test "only people from your groups with their own account can be added" do
    list = users(:alice).start_shopping_list(name: "Us")
    sign_in_as users(:alice)

    [ users(:erin), users(:dan) ].each do |someone|
      post shopping_list_shoppers_path(list), params: { shopper: { user_id: someone.id } }

      assert_response :not_found
      assert_not list.reload.shopper?(someone)
    end
  end

  test "someone who can't join is turned away" do
    list = users(:alice).start_shopping_list(name: "Us")
    items(:books).reservations.create!(user: users(:alice), shopping_list: list)
    sign_in_as users(:alice)

    get shopping_lists_path
    assert_select "##{dom_id(list)} select option[value=?]", users(:carol).id.to_s, count: 0

    post shopping_list_shoppers_path(list), params: { shopper: { user_id: users(:carol).id } }

    assert_equal I18n.t("activerecord.errors.messages.cannot_join", name: users(:carol).name), flash[:alert]
    assert_not list.reload.shopper?(users(:carol))
  end

  test "leaving a list" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    sign_in_as users(:bob)

    delete shopping_list_shopper_path(list, list.shoppers.find_by!(user: users(:bob)))

    assert_redirected_to shopping_lists_path
    assert_equal I18n.t("shopping_lists.shoppers.destroy.left", list: "Us"), flash[:notice]
    assert_equal [ users(:alice) ], list.reload.people
  end

  test "taking someone else off a list" do
    list = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    sign_in_as users(:alice)

    delete shopping_list_shopper_path(list, list.shoppers.find_by!(user: users(:bob)))

    assert_equal I18n.t("shopping_lists.shoppers.destroy.removed", name: users(:bob).name, list: "Us"), flash[:notice]
    assert_equal [ users(:alice) ], list.reload.people
  end

  test "with more than one list to choose from, you pick which one a gift goes on" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    sign_in_as users(:alice)

    get person_path(users(:carol))
    assert_select "##{dom_id(items(:books))} select[name='reservation[shopping_list_id]']", count: 2 do
      assert_select "option", text: I18n.t("shopping_lists.own")
      assert_select "option", text: us.name
    end

    post item_reservation_path(items(:books)), params: { reservation: { shopping_list_id: us.id } }

    assert_equal us, items(:books).reservations.find_by!(user: users(:alice)).shopping_list
  end

  test "with only your own list there's nothing to pick" do
    sign_in_as users(:alice)

    get person_path(users(:carol))

    assert_select "##{dom_id(items(:books))} select[name='reservation[shopping_list_id]']", count: 0
  end

  test "a gift can't go on a list you aren't on" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    sign_in_as users(:carol)

    post item_reservation_path(items(:scarf)), params: { reservation: { shopping_list_id: us.id } }

    assert_response :not_found
  end

  test "joining a split onto a list you share" do
    us = users(:carol).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    kite = users(:dan).items.create!(name: "Kite")
    split = kite.reserve_for(users(:alice), split_with: 2)
    sign_in_as users(:carol)

    get root_path
    assert_select "#splits select[name='share[shopping_list_id]'] option", count: 2

    post item_split_share_path(kite, split), params: { share: { shopping_list_id: us.id } }

    assert_equal us, split.shares.find_by!(user: users(:carol)).shopping_list
  end

  test "your shopping list shows what everyone on your lists has picked, and who picked it" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    items(:books).reserve_for(users(:bob), shopping_list: us)
    sign_in_as users(:alice)

    get root_path

    assert_select "#shopping-list a", text: items(:books).name
    assert_select "#shopping-list p", text: I18n.t("groups.shopping_list.picked", list: us.name, name: users(:bob).name)
  end

  test "anyone on a list can tick off what's on it, and put it back" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    reservation = items(:books).reserve_for(users(:bob), shopping_list: us)
    sign_in_as users(:alice)

    get root_path
    assert_select "#shopping-list form[action=?]", reservation_purchase_path(reservation)

    post reservation_purchase_path(reservation)
    assert reservation.reload.bought?

    delete reservation_purchase_path(reservation)
    assert_not reservation.reload.bought?
  end

  test "anyone on a list can let go of something on it" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    reservation = items(:books).reserve_for(users(:bob), shopping_list: us)
    sign_in_as users(:alice)

    delete reservation_path(reservation)

    assert_not Reservation.exists?(reservation.id)
  end

  test "people who aren't on a list can't tick off what's on it" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    reservation = items(:books).reserve_for(users(:bob), shopping_list: us)
    reservation.buy
    sign_in_as users(:erin)

    post reservation_purchase_path(reservation)
    assert_response :not_found

    delete reservation_purchase_path(reservation)
    assert_response :not_found

    delete reservation_path(reservation)
    assert_response :not_found
    assert reservation.reload.bought?
  end

  test "anyone on a list can leave a split that someone on it joined" do
    us = users(:carol).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    kite = users(:dan).items.create!(name: "Kite")
    split = kite.reserve_for(users(:alice), split_with: 1)
    split.join(users(:bob), shopping_list: us)
    sign_in_as users(:carol)

    get root_path
    assert_select "#shopping-list li button", text: I18n.t("groups.shopping_list.leave_split")

    delete item_split_share_path(kite, split)

    assert_empty split.reload.shares
  end

  test "anyone on a list can call off a split on it that's still waiting" do
    us = users(:carol).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    split = users(:dan).items.create!(name: "Kite").reserve_for(users(:bob), split_with: 1, shopping_list: us)
    sign_in_as users(:carol)

    get root_path
    assert_select "#splits form[action=?]", reservation_path(split)

    delete reservation_path(split)

    assert_not Reservation.exists?(split.id)
  end

  test "only whoever picked something changes which occasion it's for" do
    us = users(:alice).start_shopping_list(name: "Us", person_ids: [ users(:bob).id ])
    reservation = items(:books).reserve_for(users(:bob), shopping_list: us)
    sign_in_as users(:alice)

    assert_no_changes -> { reservation.reload.occasion } do
      patch item_reservation_path(items(:books)), params: { reservation: { occasion_id: "" } }
    end
    assert_response :not_found
  end

  test "renaming a list" do
    list = users(:alice).start_shopping_list(name: "Us")
    sign_in_as users(:alice)

    new_name = "Christmas with Bob"
    patch shopping_list_path(list), params: { shopping_list: { name: new_name } }

    assert_redirected_to shopping_lists_path
    assert_equal new_name, list.reload.name
  end
end
