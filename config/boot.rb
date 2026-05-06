ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

begin
  require "bootsnap/setup" # Speed up boot time by caching expensive operations.
rescue LoadError
  # Native extension can be stale after a Ruby upgrade while vendor/bundle persists
  # ("incompatible library version - bootsnap.so"). Boot without Bootsnap in that case.
end
