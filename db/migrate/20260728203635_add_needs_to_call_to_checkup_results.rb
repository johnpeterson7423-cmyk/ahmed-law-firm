class AddNeedsToCallToCheckupResults < ActiveRecord::Migration[7.2]
  def change
    add_column :checkup_results, :needs_to_call, :boolean, default: false, null: false
    add_index :checkup_results, [:checkup_run_id, :needs_to_call]
  end
end
