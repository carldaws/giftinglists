module ShoppingListChoice
  extend ActiveSupport::Concern

  private
    def chosen_shopping_list(scope)
      id = params.dig(scope, :shopping_list_id)
      Current.user.shopping_lists.find(id) if id.present?
    end
end
