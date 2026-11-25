class Shopper < ApplicationRecord
  belongs_to :shopping_list
  belongs_to :user
end
