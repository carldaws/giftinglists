class Shopping
  include Enumerable

  def initialize(user)
    @user = user
  end

  def each(&)
    reservations.each(&)
  end

  def to_buy
    reject(&:bought?)
  end

  def bought
    select(&:bought?)
  end

  def ours?(reservation)
    shopping_list_ids.include?(reservation.shopping_list_id)
  end

  def joined?(reservation)
    reservation.shares.any? { shopping_list_ids.include?(it.shopping_list_id) }
  end

  def pick_for(reservation)
    ours?(reservation) ? reservation : reservation.shares.find { shopping_list_ids.include?(it.shopping_list_id) }
  end

  private
    def reservations
      @reservations ||= begin
        reservations = Reservation.visible_to(@user).on(@user.shopping_lists)
          .includes(:user, :sharers, :shopping_list, occasion: :person, item: :owner, shares: %i[ user shopping_list ]).reject { it.waiting? || it.given? }
        dated, undated = reservations.partition { it.occasion.present? }

        dated.sort_by { [ it.occasion.date, it.item.owner.name.downcase ] } + undated.sort_by { it.item.owner.name.downcase }
      end
    end

    def shopping_list_ids
      @shopping_list_ids ||= @user.shopping_list_ids
    end
end
