require "signet/oauth_2/client"

module Google
  class OauthClient
    SCOPES = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/spreadsheets"

    ].freeze

    REDIRECT_URI = "http://localhost:3000/oauth2callback".freeze

    def self.client
      Signet::OAuth2::Client.new(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        authorization_uri: "https://accounts.google.com/o/oauth2/auth",
        token_credential_uri: "https://oauth2.googleapis.com/token",
        scope: SCOPES,
        redirect_uri: REDIRECT_URI
      )
    end
  end
end