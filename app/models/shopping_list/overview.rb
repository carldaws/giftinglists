class ShoppingList::Overview
  attr_reader :shopping_list, :viewer

  def initialize(shopping_list, viewer:)
    @shopping_list, @viewer = shopping_list, viewer
  end

  def shoppers
    @shoppers ||= shopping_list.shoppers.by_name.includes(:user)
  end

  def you?(shopper)
    shopper.user == viewer
  end

  def people_to_add
    @people_to_add ||= shopping_list.people_addable_by(viewer).to_a
  end
end
