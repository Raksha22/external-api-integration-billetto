Rails.application.routes.draw do
  resources :events, only: [:index] do
    collection do
      post :sync
    end
    resource :vote, only: [:create], controller: "event_votes"
  end

  root "events#index"
end
