require "google/apis/oauth2_v2"
module Google
    class OauthService
  
      SCOPES = [
        "openid",
        "email",
        "profile",
  "https://www.googleapis.com/auth/spreadsheets"
      ].freeze
  
      REDIRECT_URI = "http://localhost:3000/oauth2callback".freeze
  
  
      def initialize(code)
        @code = code
      end
  
  
      def call
        token_response = fetch_token
  
        {
          token: token_response,
          user_info: fetch_user_info(token_response["access_token"])
        }
      end
  
  
      private
  
  
      attr_reader :code
  
  
      def client
        @client ||= Signet::OAuth2::Client.new(
          client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
          client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
          authorization_uri: "https://accounts.google.com/o/oauth2/auth",
          token_credential_uri: "https://oauth2.googleapis.com/token",
          redirect_uri: REDIRECT_URI
        )
      end
  
  
      def fetch_token
        client.code = code
  
        client.fetch_access_token!
      end
  
  
      def fetch_user_info(access_token)
        service = Google::Apis::Oauth2V2::Oauth2Service.new
  
        service.authorization = Signet::OAuth2::Client.new(
          access_token: access_token
        )
  
        service.get_userinfo
      end
  
    end
  end