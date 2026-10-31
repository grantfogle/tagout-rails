Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "home#index", as: :authenticated_root
  end

  unauthenticated do
    root "home#index"
  end

  get "/dashboard", to: "dashboard#index"
  get "/features", to: "features#index"

  resource :profile, only: [:new, :create, :edit, :update]
  resources :hunt_stats, only: [:new, :create, :show]
  resources :feedbacks, only: [:create]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
