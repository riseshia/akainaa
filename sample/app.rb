# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'securerandom'

require_relative './user'
require_relative './notification'
require_relative './util'

class App < Sinatra::Base
  enable :logging

  get '/api/me' do
    1.times { Util.do_something }
    2.times { Util.do_something }
    3.times { Util.do_something }
    4.times { Util.do_something }
    5.times { Util.do_something }
    6.times { Util.do_something }
    7.times { Util.do_something }
    8.times { Util.do_something }
    9.times { Util.do_something }
    10.times { Util.do_something }

    json(
      name: "riseshia",
    )
  end
end
