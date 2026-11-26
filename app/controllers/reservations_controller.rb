class ReservationsController < ApplicationController
  def destroy
    reservation = Current.user.shopping_list_reservations.find(params[:id])
    reservation.destroy
    track_event "reservation-cancelled"
    redirect_back_or_to person_path(reservation.item.owner)
  end
end
