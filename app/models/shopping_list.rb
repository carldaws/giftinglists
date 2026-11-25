class ShoppingList < ApplicationRecord
  belongs_to :user, optional: true, inverse_of: :own_shopping_list

  has_many :shoppers, dependent: :destroy
  has_many :people, through: :shoppers, source: :user
  has_many :reservations, dependent: :restrict_with_exception
  has_many :shares, dependent: :restrict_with_exception
end
