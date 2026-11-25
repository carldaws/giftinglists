class Item::Card
  attr_reader :item, :reservations

  delegate :viewer, :occasion_choices, :split_candidates, :shopping_list_choices, :surprises_hidden?, to: :@wishlist

  def initialize(item, wishlist:, reservations: [])
    @item, @wishlist, @reservations = item, wishlist, reservations
  end

  def reservations_shown?
    !surprises_hidden?
  end

  def actions?
    reservations_shown? || editable? || receivable?
  end

  def badges?
    item.most_wanted? || item.little? || item.suggestion?
  end

  def main_photo
    item.photos.first
  end

  def extra_photos
    item.photos.drop(1)
  end

  def my_reservation
    reservations.find { it.user == viewer }
  end

  def joined_split
    reservations.find { it.sharers.include?(viewer) }
  end

  def joinable_splits
    shopping_lists_to_join_on.any? ? reservations.select(&:waiting?) : []
  end

  def reservable?
    (item.unlimited? || (reservations - [ my_reservation ]).size < item.quantity) && shopping_lists_to_reserve_on.any?
  end

  def shopping_lists_to_reserve_on
    @shopping_lists_to_reserve_on ||= shopping_list_choices.reject { it.with_any_of?(people_splitting_it) }
  end

  def shopping_lists_to_split_on
    @shopping_lists_to_split_on ||= shopping_lists_to_join_on.select { people_to_split_with_on(it).any? }
  end

  def shopping_lists_to_join_on
    @shopping_lists_to_join_on ||= shopping_list_choices.reject { it.with_any_of?(people_getting_it) }
  end

  def split_limit
    shopping_lists_to_split_on.map { people_to_split_with_on(it).size }.max.to_i
  end

  def splittable?
    split_limit.positive?
  end

  def choosing_occasion?
    my_reservation.present? && !my_reservation.given? && occasion_choices.any?
  end

  def occasion_shown_for?(reservation)
    !(choosing_occasion? && reservation == my_reservation)
  end

  def editable?
    item.editable_by?(viewer)
  end

  def receivable?
    item.receivable_by?(viewer)
  end

  def given?
    item.given_with?(reservations)
  end

  private
    def people_getting_it
      @people_getting_it ||= item.people_getting_it
    end

    def people_splitting_it
      @people_splitting_it ||= item.people_splitting_it
    end

    def people_to_split_with_on(shopping_list)
      split_candidates - people_getting_it - shopping_list.people
    end
end
