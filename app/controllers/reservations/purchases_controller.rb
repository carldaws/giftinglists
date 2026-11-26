class Reservations::PurchasesController < ApplicationController
  include ReservationScoped

  def create
    @reservation.buy

    if @reservation.errors.none?
      track_event "item-bought", occasion: @reservation.occasion_kind, occasions_bought_for: Current.user.occasions_bought_for
      redirect_back_or_to_list
    else
      redirect_back_or_to_list alert: @reservation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @reservation.unbuy
    track_event "purchase-undone"
    redirect_back_or_to_list
  end
end
