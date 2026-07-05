# frozen_string_literal: true

require "hanami"
require_relative "../../errors"

module Hanami
  module CLI
    module Commands
      module App
        # @since 3.0.0
        # @api private
        class Test < Hanami::CLI::Command
          RunError = Class.new(StandardError)

          desc "Run tests"

          example [
            "                                      # Run all tests",
            "test/path/to/some_test.rb             # Run a single test"
          ]

          argument :path, required: false, desc: "Path to a test file"
          option :verbose, required: false, desc: "Verbose output", type: :flag, default: false

          def initialize(command_exit: method(:exit), **opts)
            super(**opts)
            @command_exit = command_exit
          end

          def call(path: nil, verbose: false, **)
            ENV["HANAMI_ENV"] ||= "test"

            require "hanami/prepare"

            $LOAD_PATH << Hanami.app.root.join("test")

            ARGV.replace(["-v", "--"]) if verbose

            paths = if path.nil?
                      Hanami.app.root.glob("test/**/*_test.rb").map(&:to_s)
                    elsif Dir.exist?(path)
                      Dir.glob(File.join(path, "**/*_test.rb"))
                    elsif File.exist?(path)
                      Array(path)
                    else
                      raise RunError, "Error: missing `#{path}`"
                    end.flatten

            paths
              .each { validate_file_path!(_1) }
              .each { Kernel.load _1 }
          rescue RunError
            @command_exit.call(1)
          end

          private

          def validate_file_path!(file_path)
            errors = []

            # Ensure the file is a Ruby file
            unless file_path.end_with?(".rb")
              errors << "Error: Only Ruby files (.rb) are allowed"
            end

            # Resolve the absolute path and ensure it's within the app directory
            resolved_path = File.expand_path(file_path)
            app_root = Hanami.app.root.to_s

            unless resolved_path.start_with?(app_root)
              errors << "Error: File must be within the application directory"
            end

            # Check file size (prevent loading extremely large files)
            file_size = File.size(file_path)
            if file_size > 10 * 1024 * 1024 # 10MB limit
              errors << "Error: File too large (maximum 10MB allowed)"
            end

            unless errors.empty?
              errors.each { |error| err.puts error }
              raise RunError, errors.join("\n")
            end
          end
        end
      end
    end
  end
end
