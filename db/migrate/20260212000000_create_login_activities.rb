class CreateLoginActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :login_activities, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :ip_address
      t.string :user_agent
      t.string :country
      t.string :city
      t.boolean :unusual, default: false, null: false

      t.datetime :created_at, null: false
    end

    add_index :login_activities, [ :user_id, :created_at ]
    add_index :login_activities, [ :user_id, :unusual ]
  end
end
