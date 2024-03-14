# frozen_string_literal: true

require 'akainaa'

Akainaa.start(project_dir: File.expand_path(__dir__))

require_relative 'app'

use Akainaa::Middleware
run App
