class Items::Splits::SharesController < ApplicationController
  include ItemScoped, ShoppingListChoice

  before_action :set_split

  def create
    share = @split.join(Current.user, shopping_list: chosen_shopping_list(:share))

    if share.persisted?
      track_event "split-joined", shared_list: !share.shopping_list.own?
      redirect_back_or_to_list
    else
      redirect_back_or_to_list alert: share.errors.full_messages.to_sentence
    end
  end

  def destroy
    share = @split.shares.find_by!(shopping_list: Current.user.shopping_lists)
    share.leave

    if share.destroyed?
      track_event "split-left"
      redirect_back_or_to_list
    else
      redirect_back_or_to_list alert: share.errors.full_messages.to_sentence
    end
  end

  private
    def set_split
      @split = Reservation.visible_to(Current.user).splits.where(item: @item).find(params[:split_id])
    end
end
