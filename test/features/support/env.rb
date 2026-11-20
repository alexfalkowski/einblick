# frozen_string_literal: true

lib = File.expand_path('../../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'nonnative'
require 'einblick'

World(Einblick::OTLP::World)
World(Einblick::Startup::World)
World(Einblick::Logs::World)
World(Einblick::Migrate::World)
World(Einblick::Site::World)
