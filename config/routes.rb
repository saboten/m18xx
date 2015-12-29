Rails.application.routes.draw do
  resources :game_sessions do
    member do
      post 'command'
      post 'final_score'
    end
  end

  root 'game_sessions#index'
end
