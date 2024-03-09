# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'securerandom'

class Counter
  def initialize
    @value = 0
  end

  def incr
    @value += 1
  end
end

class App < Sinatra::Base
  enable :logging

  helpers do
    def counter
      @counter ||= Counter.new
    end

    def fetch_recipes
      10.times.map do
        i = counter.incr
        {
          id: i,
          name: "Recipe ##{i}",
          author: fetch_user,
        }
      end
    end

    def fetch_user
      {
        id: counter.incr,
        name: SecureRandom.uuid,
      }
    end
  end

  get '/api/me' do
    json(
      id: counter.incr,
      name: "riseshia",
      recipes: fetch_recipes,
    )
  end
end
