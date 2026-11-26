module ShoppingListsHelper
  def shopping_list_name(shopping_list)
    shopping_list.own? ? t("shopping_lists.own") : shopping_list.name
  end

  def shopping_list_options(shopping_lists)
    shopping_lists.map { [ shopping_list_name(it), it.id ] }
  end
end
