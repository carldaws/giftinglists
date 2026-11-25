class ShoppingLists::ShoppersController < ApplicationController
  before_action :set_shopping_list

  def create
    person = Current.user.possible_shoppers.find(params.expect(shopper: [ :user_id ]).fetch(:user_id))
    shopper = @shopping_list.shoppers.create_or_find_by(user: person)

    if shopper.persisted?
      track_event "shopper-added" if shopper.previously_new_record?
      redirect_to shopping_lists_path, notice: t(".added", name: person.name, list: @shopping_list.name)
    else
      redirect_to shopping_lists_path, alert: shopper.errors.full_messages.to_sentence
    end
  end

  def destroy
    shopper = @shopping_list.shoppers.find(params[:id])
    shopper.leave

    if shopper.user == Current.user
      track_event "shopping-list-left"
      redirect_to shopping_lists_path, notice: t(".left", list: @shopping_list.name)
    else
      track_event "shopper-removed"
      redirect_to shopping_lists_path, notice: t(".removed", name: shopper.user.name, list: @shopping_list.name)
    end
  end

  private
    def set_shopping_list
      @shopping_list = Current.user.shopping_lists.shared.find(params[:shopping_list_id])
    end
end
