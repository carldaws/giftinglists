module Reservation::Splittable
  extend ActiveSupport::Concern

  included do
    has_many :shares, dependent: :destroy
    has_many :sharers, through: :shares, source: :user

    validates :split_with, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validate :user_is_not_already_splitting_it, on: :create, if: -> { item.present? && user.present? && errors.none? }
    validate :split_fits_the_people_who_can_join, on: :create, if: -> { split? && item.present? && user.present? && errors.none? }
    validate :split_is_complete_before_buying, if: -> { split? && will_save_change_to_bought_at? && bought? }

    scope :splits, -> { where.not(split_with: nil) }
    scope :involving, ->(user) { where(user:).or(where(id: Share.where(user:).select(:reservation_id))) }
    scope :on, ->(shopping_lists) { where(shopping_list: shopping_lists).or(where(id: Share.where(shopping_list: shopping_lists).select(:reservation_id))) }
  end

  def split?
    split_with.present?
  end

  def people
    [ user, *sharers ]
  end

  def shopping_lists
    [ shopping_list, *shares.map(&:shopping_list) ]
  end

  def started_by?(person)
    user == person
  end

  def joined_by?(person)
    sharers.include?(person)
  end

  def places_left
    split? ? split_with - shares.size : 0
  end

  def waiting?
    split? && !bought? && places_left.positive?
  end

  def fillable?
    item.people_to_split_with(user).count >= places_left
  end

  def joinable_by?(person)
    waiting? && item.still_wanted? && item.people_getting_it.exclude?(person)
  end

  def shopping_lists_to_join_for(person)
    getting = item.people_getting_it
    person.shopping_lists_for_gifts_to(item.owner).reject { it.with_any_of?(getting) }
  end

  def join(person, shopping_list: nil)
    item.with_lock { shares.create_with(shopping_list:).find_or_create_by(user: person) }
  end

  def hand_over
    successor = shares.sort_by(&:created_at).find { Item.visible_to(it.user).exists?(item_id) }

    if successor.present?
      transaction do
        successor.destroy!
        update!(user: successor.user, shopping_list: successor.shopping_list)
      end
    end
  end

  def give_up
    hand_over || destroy
  end

  private
    def user_is_not_already_splitting_it
      errors.add(:base, :already_getting_it) if Share.where(reservation: item.reservations, user:).exists?
    end

    def split_fits_the_people_who_can_join
      available = item.people_to_split_with(user).where.not(id: shopping_list.shoppers.select(:user_id)).count
      errors.add(:split_with, :too_many, count: available) if split_with > available
    end

    def split_is_complete_before_buying
      errors.add(:base, :split_incomplete) if places_left.positive?
    end
end
