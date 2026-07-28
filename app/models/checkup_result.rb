class CheckupResult < ApplicationRecord
  belongs_to :checkup_run

  STATUSES = %w[found not_found].freeze

  validates :status, inclusion: { in: STATUSES }
end
