class ShoppingListsController < ApplicationController
  before_action :set_shopping_list, only: %i[ edit update ]

  def index
    @overviews = Current.user.shopping_lists.shared.by_name.map { ShoppingList::Overview.new(it, viewer: Current.user) }
  end

  def new
    @shopping_list = ShoppingList.new
  end

  def create
    @shopping_list = Current.user.start_shopping_list(params.expect(shopping_list: [ :name, person_ids: [] ]))

    if @shopping_list.persisted?
      track_event "shopping-list-created", people: @shopping_list.people.size
      redirect_to shopping_lists_path, notice: t(".created", list: @shopping_list.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @shopping_list.update(params.expect(shopping_list: [ :name ]))
      redirect_to shopping_lists_path, notice: t(".renamed")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_shopping_list
      @shopping_list = Current.user.shopping_lists.shared.find(params[:id])
    end
end
