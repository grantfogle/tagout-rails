Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
    # config/routes.rb
  end

  unauthenticated do
    root "home#index"
  end

  get "/dashboard", to: "dashboard#index"

  resources :hunt_stats, only: [:new, :create, :show]
  resources :feedbacks, only: [:create]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
