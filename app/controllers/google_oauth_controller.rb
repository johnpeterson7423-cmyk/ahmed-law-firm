class GoogleOauthController < ApplicationController

    def login
      redirect_to authorization_uri, allow_other_host: true
    end
  
  
    def callback
      result = Google::OauthService.new(params[:code]).call
  
      token = result[:token]
      user_info = result[:user_info]
  
  
      user = User.find_or_initialize_by(
        google_uid: user_info.id
      )
  
  
      attrs = {
        name: user_info.name,
        email: user_info.email,
        access_token: token["access_token"],
        token_expires_at: Time.current + token["expires_in"].to_i.seconds
      }
      attrs[:refresh_token] = token["refresh_token"] if token["refresh_token"].present?

      user.update!(attrs)
  
  
      session[:user_id] = user.id
  
  
      redirect_to root_path,
                  notice: "Google connected successfully"
    end
  
  
    private
  
  
    def authorization_uri
      Google::OauthClient.client.authorization_uri(
        access_type: "offline",
        prompt: "consent"
      )
    end
  
  end