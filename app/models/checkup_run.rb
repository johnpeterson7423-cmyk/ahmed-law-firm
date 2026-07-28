class CheckupRun < ApplicationRecord
  belongs_to :user
  has_many :checkup_results, dependent: :destroy

  STATUSES = %w[pending running done error].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def running?
    status.in?(%w[pending running])
  end
end
