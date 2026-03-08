class EnterpriseModule < ApplicationRecord
  belongs_to :enterprise
  belongs_to :feature_module

  validates :feature_module_id, uniqueness: { scope: :enterprise_id }
end
