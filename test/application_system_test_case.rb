require "test_helper"
require "capybara/selenium/driver"

Capybara.enable_aria_label = true
Capybara.default_max_wait_time = 5

module ClearCookiesWithoutWildcardOrigin
  private
    def execute_cdp(command, params = {})
      if command == "Storage.clearDataForOrigin" && params[:origin] == "*"
        super("Network.clearBrowserCookies")
      else
        super
      end
    end
end

Capybara::Selenium::Driver::ChromeDriver.prepend ClearCookiesWithoutWildcardOrigin

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ]
end
