class User < ApplicationRecord

    validates :email, presence: true
    validates :google_uid, presence: true
  
  end   