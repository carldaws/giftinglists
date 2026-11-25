module ReservationScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_reservation
  end

  private
    def set_reservation
      @reservation = Current.user.shopping_list_reservations.find(params[:reservation_id])
    end

    def redirect_back_or_to_list(**flash)
      redirect_back_or_to person_path(@reservation.item.owner), **flash
    end
end
