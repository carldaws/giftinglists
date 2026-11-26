class Items::ReservationsController < ApplicationController
  include ItemScoped, ShoppingListChoice

  def create
    reservation = @item.reserve_for(Current.user, split_with: params.dig(:reservation, :split_with), shopping_list: chosen_shopping_list(:reservation))

    if reservation.persisted?
      track_event "item-reserved", split: reservation.split?, occasion: reservation.occasion_kind, shared_list: !reservation.shopping_list.own?
      redirect_back_or_to_list
    else
      redirect_back_or_to_list alert: reservation.errors.full_messages.to_sentence
    end
  end

  def update
    reservation = Current.user.reservations.find_by!(item: @item)

    if reservation.update(params.expect(reservation: [ :occasion_id ]))
      redirect_back_or_to_list
    else
      redirect_back_or_to_list alert: reservation.errors.full_messages.to_sentence
    end
  end
end
