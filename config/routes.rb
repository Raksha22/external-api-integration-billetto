Rails.application.routes.draw do
  resources :events, only: [:index] do
    collection do
      post :sync
    end
  end

  root "events#index"
end
