Rails.application.routes.draw do
  root "fiscal_years#index"

  resources :fiscal_years do
    resource :salary_income, only: [ :show, :new, :create, :edit, :update, :destroy ]
    resources :revenues
    resources :expenses
    resources :deductions
    resources :journal_entries, only: [ :index, :new, :create, :edit, :update, :destroy ]

    member do
      get :tax_summary
      get :journal
      get :general_ledger
      get :income_statement
      get :balance_sheet
    end
  end

  resources :accounts, only: [ :index, :new, :create, :edit, :update ]

  get "up" => "rails/health#show", as: :rails_health_check
end
