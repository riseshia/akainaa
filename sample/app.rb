# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'securerandom'

require_relative './user'

class App < Sinatra::Base
  enable :logging

  helpers do
    def fetch_tsukurepos(recipe_id)
      3.times.map do |i|
        {
          id: i,
          recipe_id: recipe_id,
          text: "Tsukurepo ##{i}",
          author: fetch_user,
        }
      end
    end

    def fetch_recipes
      5.times.map do |i|
        {
          id: i,
          name: "Recipe ##{i}",
          author: fetch_user,
          tsukurepos: fetch_tsukurepos(i),
        }
      end
    end

    def fetch_user
      id = SecureRandom.uuid

      User.find(id)
    end

    def fetch_theme(_id)
      "light"
    end
  end

  get '/api/me' do
    json(
      name: "riseshia",
      recipes: fetch_recipes,
    )
  end
end
