# frozen_string_literal: true

module Einblick
  module Startup
    # Runs the failing startup independently of the suite's healthy server.
    module World
      # Captures the CLI failure, bounding the attempt with the harness timeout.
      def attempt_database_start(config)
        timeout = Nonnative.configuration.process_by_name('server').timeout
        Open3.popen2e('../einblick', 'server', '-config', "file:.config/#{config}") do |input, output, process|
          input.close
          @startup_status = Nonnative::Timeout.new(timeout).perform do
            @startup_output = output.read
            process.value
          end
        ensure
          Process.kill('INT', process.pid) if process.alive?
        end
      end
    end
  end
end
