class CreateShoppingLists < ActiveRecord::Migration[8.1]
  def change
    create_table :shopping_lists do |t|
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :name
      t.timestamps

      t.check_constraint "num_nonnulls(user_id, name) = 1", name: "shopping_lists_are_someones_own_or_named"
    end

    create_table :shoppers do |t|
      t.references :shopping_list, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.timestamps

      t.index %i[ shopping_list_id user_id ], unique: true
    end

    add_reference :reservations, :shopping_list, foreign_key: true
    add_reference :shares, :shopping_list, foreign_key: true

    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO shopping_lists (user_id, created_at, updated_at)
          SELECT id, NOW(), NOW() FROM users WHERE email_address IS NOT NULL
        SQL
        execute <<~SQL
          INSERT INTO shoppers (shopping_list_id, user_id, created_at, updated_at)
          SELECT id, user_id, NOW(), NOW() FROM shopping_lists
        SQL
        execute <<~SQL
          UPDATE reservations SET shopping_list_id = shopping_lists.id
          FROM shopping_lists WHERE shopping_lists.user_id = reservations.user_id
        SQL
        execute <<~SQL
          UPDATE shares SET shopping_list_id = shopping_lists.id
          FROM shopping_lists WHERE shopping_lists.user_id = shares.user_id
        SQL
      end
    end

    change_column_null :reservations, :shopping_list_id, false
    change_column_null :shares, :shopping_list_id, false
  end
end
