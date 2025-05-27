Rails.application.routes.draw do
  # Xóa các route tự động được tạo ra
  # get "import_histories/index"
  # get "import_histories/show"
  # get "import_histories/revert"

  # Authentication routes
  get    "/login",   to: "sessions#new"
  post   "/login",   to: "sessions#create"
  delete "/logout",  to: "sessions#destroy"
  get    "/logout",  to: "sessions#destroy"  # Adding GET route for logout to handle cases where Turbo isn't working

  # Users routes
  get  "/signup",  to: "users#new"
  post "/signup",  to: "users#create"
  get  "/profile", to: "users#show", as: :profile
  get  "/profile/edit", to: "users#edit", as: :edit_profile
  patch "/profile", to: "users#update"

  # Language switching route
  get "/switch_language/:locale", to: "languages#switch", as: :switch_language

  # Location API routes for cascading dropdowns
  namespace :api do
    get "/cities/:country_id", to: "locations#cities", as: :cities
    get "/districts/:city_id", to: "locations#districts", as: :districts
    get "/wards/:district_id", to: "locations#wards", as: :wards
  end

  # Resource routes
  resources :buildings do
    member do
      get :import_form
      post :import_excel
    end
    resources :rooms, only: [ :index, :new, :create ]
    resources :operating_expenses, only: [ :index, :new, :create ]
    resources :smart_devices, only: [ :index, :new, :create ]
    # Thêm nested route cho import_histories
    resources :import_histories, only: [ :index ]
  end

  # Thêm routes cho import_histories
  resources :import_histories, only: [ :show ] do
    member do
      post :revert
      get :download # Cho phép tải xuống file Excel đã import
    end
  end

  resources :rooms
  resources :tenants do
    resources :vehicles, only: [ :index, :new, :create ]
  end

  # Define specific vehicle routes first to ensure proper order
  get "/vehicles/new", to: "vehicles#new", as: :new_vehicle
  post "/vehicles", to: "vehicles#create"
  # Then define the rest of the vehicle resources
  resources :vehicles, except: [ :new, :create ]

  # Define smart device routes
  resources :smart_devices do
    collection do
      match :sync_devices, via: [ :get, :post ]
      get "job_progress/:job_id", to: "smart_devices#job_progress", as: :job_progress
      post "stop_sync_job/:job_id", to: "smart_devices#stop_sync_job", as: :stop_sync_job
    end

    member do
      get :device_info
      get :device_functions
      get :device_logs

      # Smart lock routes
      match :unlock_door, via: [ :get, :post ]
      match :lock_door, via: [ :get, :post ]
      get :battery_level
      get :password_list
      post :add_password
      delete :delete_password
      get :lock_users

      # Database sync routes
      match :sync_device_data, via: [ :get, :post ]
      match :sync_unlock_records, via:  [ :get, :post ] # New route for syncing only unlock records
      match :sync_device_users, via:  [ :get, :post ]  # New route for syncing only device users
      get :device_unlock_records
      get :device_users
      post :link_user_to_tenant
      post :unlink_user_from_tenant
    end
  end

  resources :room_assignments do
    member do
      patch :end
      patch :make_representative
      patch :activate
    end
  end
  resources :utility_readings
  resources :utility_prices  # Added RESTful utility prices routes
  resources :bills do
    member do
      patch :mark_as_paid  # This creates mark_as_paid_bill_path
      get :mark_as_paid    # Adding GET route to handle direct link clicks
      post :record_payment # Thêm route mới để xử lý thanh toán một phần
    end
  end
  resources :operating_expenses

  # Contracts routes with additional actions for document management
  resources :contracts do
    member do
      get :download       # Route to download the contract document
      post :generate_pdf  # Route to generate the contract document as PDF from HTML template
      get :generate_pdf   # Also allow GET requests for the generate_pdf action
    end
    collection do
      get :room_assignment_details # Route to get room assignment details for autofill
    end
  end

  # Revenues route
  get "/revenues", to: "revenues#index", as: :revenues

  # Dashboard route
  get "/dashboard", to: "dashboard#index", as: :dashboard

  # Root path
  root "dashboard#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
