# frozen_string_literal: true

Nonnative.configure do |config|
  config.load_file('nonnative.yml')
end

require 'nonnative/startup'

After('@native_query_work') do
  restore_native_query_work
end
