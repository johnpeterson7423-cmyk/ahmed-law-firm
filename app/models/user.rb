class User < ApplicationRecord
  has_many :checkup_runs, dependent: :destroy

  validates :email, presence: true
  validates :google_uid, presence: true
end
