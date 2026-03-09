Rails.application.routes.draw do
  root "dashboard#index"
  resource :session
  get "login", to: "sessions#new", as: :login
  resource :registration, only: [ :new, :create ] do
    get :pending, on: :collection
  end
  resources :passwords, param: :token
  resources :invitations, only: [ :edit, :update ], param: :token

  namespace :admin do
    resources :enterprises, only: [ :new, :create ]
    resource :dashboard, only: [ :show ]
  end

  resources :enterprises, only: [ :index, :edit, :update ] do
    member do
      post :select
    end
    resource :modules_configuration, only: [ :show, :update ], controller: "enterprise_modules"
  end

  resources :products do
    collection do
      get :search
    end
  end
  resources :providers do
    collection do
      get :search
    end
    resources :products, only: [ :index ], controller: "provider_products"
  end
  resources :customers do
    collection do
      get :search
    end
  end
  resources :ubigeos, only: [ :index ]

  resources :customer_quotes do
    collection do
      get :prefill
    end
    member do
      patch :accept
      patch :reject
      patch :expire
      get :pdf
    end
  end

  resources :sales do
    member do
      patch :confirm
      patch :cancel
      post :generate_purchase_orders
      post :emit_document
      post :retry_document
      get :check_sunat_status
      get :pdf
      get :sunat_pdf
      get :sunat_xml
    end
  end

  resource :sunat, only: [ :show ], controller: "sunat" do
    post :register
    post :upload_certificate
    patch :update_settings
    patch :update_sol_credentials
    patch :update_sunat_rest_credentials
  end

  resources :vehicles, except: [ :show ]
  resources :carriers, except: [ :show ]

  resources :dispatch_guides do
    member do
      post :emit_document
      post :retry_document
      get :check_sunat_status
      patch :cancel
      get :pdf
      get :sunat_xml
    end
  end

  resources :purchase_orders do
    collection do
      get :prefill
    end
    member do
      patch :confirm
      patch :receive
      patch :cancel
      get :pdf
    end
  end

  resources :suggestions, only: [ :new, :create ]

  resources :bulk_imports, only: [ :index, :show, :new, :create ] do
    collection do
      get :template
    end
  end

  resources :users, except: [ :destroy ] do
    collection do
      get :search
    end
    member do
      patch :toggle_status
    end
  end

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
