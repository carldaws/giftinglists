class ShoppingList < ApplicationRecord
  belongs_to :user, optional: true, inverse_of: :own_shopping_list

  has_many :shoppers, dependent: :destroy
  has_many :people, through: :shoppers, source: :user
  has_many :reservations, dependent: :restrict_with_exception
  has_many :shares, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.squish.presence }

  validates :name, presence: true, length: { maximum: 80 }, unless: :own?
  validate :everyone_can_see_each_other, on: :create

  scope :shared, -> { where(user: nil) }
  scope :by_name, -> { order(:name) }

  def own?
    user.present?
  end

  def shopper?(person)
    people.include?(person)
  end

  def recipients
    Reservation.on(self).includes(:occasion, item: :owner).reject(&:given?).map { it.item.owner }.uniq
  end

  def people_who_can_join
    for_recipients = recipients.reduce(User.where.not(email_address: nil)) do |candidates, recipient|
      candidates.where.not(id: recipient).where(id: User.who_can_see(recipient).select(:id))
    end

    people.reduce(for_recipients) { |candidates, shopper| candidates.where(id: User.visible_to(shopper).select(:id)) }
  end

  def people_addable_by(person)
    people_who_can_join.where(id: person.possible_shoppers.select(:id)).where.not(id: shoppers.select(:user_id)).by_name
  end

  def hand_back_gifts_hidden_from(person)
    reservations.where.not(item: Item.visible_to(person)).includes(user: :own_shopping_list).find_each do |reservation|
      reservation.update_column(:shopping_list_id, reservation.user.own_shopping_list.id)
    end

    shares.where.not(reservation: Reservation.visible_to(person)).includes(user: :own_shopping_list).find_each do |share|
      share.update_column(:shopping_list_id, share.user.own_shopping_list.id)
    end
  end

  private
    def everyone_can_see_each_other
      unless people.all? { |person| User.visible_to(person).where(id: people.map(&:id)).count == people.size }
        errors.add(:base, :strangers)
      end
    end
end
