Rails.application.routes.draw do
  root "home#index"

  get "/login", to: "google_oauth#login"
  get "/oauth2callback", to: "google_oauth#callback"
  delete "/logout", to: "sessions#destroy"

  resources :sheets, only: [:index] do
    collection do
      post :export
    end
  end
end
