Rails.application.routes.draw do
  root "fiscal_years#index"

  resources :fiscal_years do
    resource :salary_income, only: [ :show, :new, :create, :edit, :update, :destroy ]
    resources :revenues
    resources :expenses
    resources :deductions
    get :tax_summary, on: :member
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
