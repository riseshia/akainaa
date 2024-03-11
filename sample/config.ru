# frozen_string_literal: true

require 'isucover'

Isucover.start

require_relative 'app'

use Isucover::Middleware
run App
