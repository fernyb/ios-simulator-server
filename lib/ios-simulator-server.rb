require 'selenium-webdriver'
require 'ios/simulator/server'


if defined?(Capybara) && defined?(Capybara::Selenium)

Selenium::WebDriver::Remote::Bridge.command :getNetworkTraffic, :get,    "/wd/hub/session/:session_id/network_traffic"
Selenium::WebDriver::Remote::Bridge.command :getCookie,         :get,    "/wd/hub/session/:session_id/cookie"
Selenium::WebDriver::Remote::Bridge.command :deleteCookie,      :delete, "/wd/hub/session/:session_id/cookie"
Selenium::WebDriver::Remote::Bridge.command :reload,            :get,    "/wd/hub/session/:session_id/reload"
Selenium::WebDriver::Remote::Bridge.command :setHeaders,        :post,   "/wd/hub/session/:session_id/headers"


Capybara::Selenium::Driver.class_eval do
  def network_traffic
    #require 'pp'
    #require './network_traffic.rb'
    # $stdout.puts "***** URL: #{ @options[:url] }\n\n"
    result = browser.send(:bridge).send(:execute, :getNetworkTraffic)
    # $stdout.puts "*** Network Traffic \n\n"
    # $stdout.puts PP.pp(result, ''), "\n\n"
    result
  end

  def cookies
    result = browser.send(:bridge).send(:execute, :getCookie)
    _cookies = {}
    (result || []).each {|c|
      _kookie = Struct.new(:name, :value, :domain, :path, :secure?, :httponly?, :expires).new(
        c['name'], c['value'], c['domain'], c['path'], c['secure'], c['httpOnly'], c['expires']
      )
      _cookies.merge!({ c['name'] => _kookie })
    }
    _cookies
  end

  def delete_cookie(name)
    browser.send(:bridge).send(:execute, :deleteCookie, {}, { :name => name })
  end

  def reload
    browser.send(:bridge).send(:execute, :reload)
  end

  def headers=(header_values)
    result = browser.send(:bridge).send(:execute, :setHeaders, {}, { :headers => header_values })
    result
  end
end

end
