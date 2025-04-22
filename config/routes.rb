Rails.application.routes.draw do
  get "dashboard/index"
  # Authentication routes
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  
  # Users routes
  get  '/signup',  to: 'users#new'
  post '/signup',  to: 'users#create'
  
  # Language switching route
  get '/switch_language/:locale', to: 'languages#switch', as: :switch_language
  
  # Resource routes
  resources :rooms
  resources :tenants
  resources :room_assignments do
    member do
      patch :end
    end
  end
  resources :utility_readings
  resources :bills do
    member do
      patch :mark_as_paid  # This creates mark_as_paid_bill_path
    end
  end
  
  # Dashboard route
  get '/dashboard', to: 'dashboard#index', as: :dashboard
  
  # Root path
  root 'dashboard#index'
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
