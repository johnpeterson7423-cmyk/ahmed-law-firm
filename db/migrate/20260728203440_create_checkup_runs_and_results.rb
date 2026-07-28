class CreateCheckupRunsAndResults < ActiveRecord::Migration[7.2]
  def change
    create_table :checkup_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :limit_count, null: false, default: 25
      t.integer :total, null: false, default: 0
      t.integer :scanned, null: false, default: 0
      t.integer :found_count, null: false, default: 0
      t.integer :not_found_count, null: false, default: 0
      t.string :query
      t.string :insurance
      t.string :filter_status
      t.string :last_client
      t.text :error
      t.jsonb :clients_payload, null: false, default: []
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    create_table :checkup_results do |t|
      t.references :checkup_run, null: false, foreign_key: true
      t.string :client, null: false, default: ""
      t.string :dol, null: false, default: ""
      t.string :last_checkup_date
      t.string :status, null: false, default: "not_found"
      t.string :document_name
      t.text :error

      t.timestamps
    end

    add_index :checkup_results, [:checkup_run_id, :status]
    add_index :checkup_runs, [:user_id, :created_at]
  end
end
