module Shoppable
  extend ActiveSupport::Concern

  included do
    belongs_to :shopping_list, default: -> { user.own_shopping_list if user.present? }
  end

  private
    def shopping_list_can_take(item, clashing_with:)
      if !user.shopping_lists.for_gifts_to(item.owner).exists?(shopping_list.id)
        errors.add(:base, :wrong_shopping_list, name: item.owner.name)
      elsif shopping_list.with_any_of?(clashing_with)
        errors.add(:base, :shopping_list_already_getting_it)
      end
    end
end
