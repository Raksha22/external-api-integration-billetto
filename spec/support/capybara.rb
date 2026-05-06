# frozen_string_literal: true

require "capybara/rails"
require "capybara/rspec"

# Default **rack_test**: fast, no Chromium; exercises HTML forms and redirects in-process (CI-friendly).
# Optional real browser: `CAPYBARA_JS_DRIVER=cuprite bundle exec rspec spec/system` (requires Chromium).
driver_name = ENV.fetch("CAPYBARA_JS_DRIVER", "rack_test")

if driver_name == "cuprite"
  require "capybara/cuprite"

  browser_options = {}
  browser_options["no-sandbox"] = nil if ENV["CI"].present?

  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(
      app,
      window_size: [1400, 900],
      browser_options: browser_options,
      headless: ENV["HEADFUL_SYSTEM_SPECS"].blank?,
      process_timeout: 30,
      timeout: 10
    )
  end
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by driver_name.to_sym
  end
end
