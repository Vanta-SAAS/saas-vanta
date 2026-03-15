class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.references :user, foreign_key: true
      t.references :enterprise, foreign_key: true
      t.string :controller_name, null: false
      t.string :action_name, null: false
      t.string :record_type
      t.bigint :record_id
      t.jsonb :request_params, default: {}
      t.string :ip_address
      t.string :http_method, null: false
      t.string :path, null: false
      t.datetime :performed_at, null: false

      t.timestamps
    end

    add_index :activity_logs, :performed_at
    add_index :activity_logs, [ :record_type, :record_id ]
    add_index :activity_logs, [ :controller_name, :action_name ]
  end
end
