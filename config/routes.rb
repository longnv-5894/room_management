Rails.application.routes.draw do
  # Remove the auto-generated buildings routes
  # get "buildings/index"
  # get "buildings/show"
  # get "buildings/new"
  # get "buildings/create"
  # get "buildings/edit"
  # get "buildings/update"
  # get "buildings/destroy"
  
  # Remove the auto-generated utility prices routes
  # get "utility_prices/index"
  # get "utility_prices/new"
  # get "utility_prices/create"
  # get "utility_prices/edit"
  # get "utility_prices/update"

  # Authentication routes
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  get    '/logout',  to: 'sessions#destroy'  # Adding GET route for logout to handle cases where Turbo isn't working

  # Users routes
  get  '/signup',  to: 'users#new'
  post '/signup',  to: 'users#create'
  get  '/profile', to: 'users#show', as: :profile
  get  '/profile/edit', to: 'users#edit', as: :edit_profile
  patch '/profile', to: 'users#update'

  # Language switching route
  get '/switch_language/:locale', to: 'languages#switch', as: :switch_language

  # Resource routes
  resources :buildings do
    resources :rooms, only: [:index, :new, :create]
    resources :operating_expenses, only: [:index, :new, :create]
  end
  resources :rooms
  resources :tenants do
    resources :vehicles, only: [:index, :new, :create]
  end

  # Define specific vehicle routes first to ensure proper order
  get '/vehicles/new', to: 'vehicles#new', as: :new_vehicle
  post '/vehicles', to: 'vehicles#create'
  # Then define the rest of the vehicle resources
  resources :vehicles, except: [:new, :create]

  resources :room_assignments do
    member do
      patch :end
    end
  end
  resources :utility_readings
  resources :utility_prices  # Added RESTful utility prices routes
  resources :bills do
    member do
      patch :mark_as_paid  # This creates mark_as_paid_bill_path
      get :mark_as_paid    # Adding GET route to handle direct link clicks
    end
  end
  resources :operating_expenses

  # Revenues route
  get '/revenues', to: 'revenues#index', as: :revenues

  # Dashboard route
  get '/dashboard', to: 'dashboard#index', as: :dashboard

  # Root path
  root 'dashboard#index'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
