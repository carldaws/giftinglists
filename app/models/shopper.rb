class Shopper < ApplicationRecord
  belongs_to :shopping_list
  belongs_to :user

  validate :user_can_join, on: :create, if: -> { shopping_list.present? && shopping_list.persisted? && user.present? }

  after_destroy :close_list_if_empty, unless: -> { shopping_list.own? || destroyed_with_list? }

  scope :by_name, -> { joins(:user).merge(User.by_name) }
  scope :on_shared_lists, -> { joins(:shopping_list).merge(ShoppingList.shared) }

  def can_see_everyone?
    shopping_list.people.all? { it.visible_to?(user) }
  end

  def leave
    transaction do
      take_picks_to_own_list
      destroy!
    end
  end

  private
    def user_can_join
      if shopping_list.own?
        errors.add(:base, :someone_elses_own_list) unless shopping_list.user == user
      elsif !shopping_list.people_who_can_join.exists?(user.id)
        errors.add(:base, :cannot_join, name: user.name)
      end
    end

    def take_picks_to_own_list
      shopping_list.reservations.where(user:).update_all(shopping_list_id: user.own_shopping_list.id)
      shopping_list.shares.where(user:).update_all(shopping_list_id: user.own_shopping_list.id)
    end

    def close_list_if_empty
      shopping_list.destroy! unless shopping_list.shoppers.exists?
    end

    def destroyed_with_list?
      destroyed_by_association.present? && destroyed_by_association.active_record == ShoppingList
    end
end
