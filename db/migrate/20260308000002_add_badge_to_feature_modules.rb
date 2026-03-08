class AddBadgeToFeatureModules < ActiveRecord::Migration[8.0]
  def change
    add_column :feature_modules, :badge, :string
  end
end
