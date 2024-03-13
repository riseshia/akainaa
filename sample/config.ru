# frozen_string_literal: true

require 'isucover'

Isucover.start(project_dir: File.expand_path(__dir__))

require_relative 'app'

use Isucover::Middleware
run App
