ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "logger"        # Fix concurrent-ruby 1.3.5 + Rails 6.1 logger issue
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
