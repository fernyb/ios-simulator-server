require 'thin'
require 'sinatra'
require 'sinatra/contrib'
require 'securerandom'
require 'json'
require 'active_support'
require 'active_support/hash_with_indifferent_access'
require 'net/http'
require "ios-simulator-server/server/bridge.rb"


class SeleniumServer < Sinatra::Base

set :server,  'thin'
set :port,    4444
set :bind,    '0.0.0.0'


$connections = {}

# Documentation:
# https://code.google.com/p/selenium/wiki/JsonWireProtocol#/sessions

get "/" do
  "Hello World"
end

get "/status" do
end

namespace "/wd/hub" do
  post "/session" do
    content_type :json
    _uuid_ = SecureRandom.uuid

    $connections[_uuid_] = {}

    uri = URI('http://localhost:9222/json')
    res = Net::HTTP.get_response(uri)
    pages = JSON.parse(res.body)
    websocket_uri = pages.first['webSocketDebuggerUrl']

    $connections[_uuid_][:bridge] = Bridge.new(websocket_uri)

    {
      :status    => 0,
      :sessionId => _uuid_,
      :value     => {
        :platform                 => "iOS Simulator",
        :browserName              => :MobileSafari,
        :javascriptEnabled        => true,
        :takesScreenshot          => true,
        :handlesAlerts            => true,
        :databaseEnabled          => false,
        :locationContextEnabled   => false,
        :applicationCacheEnabled  => false,
        :browserConnectionEnabled => false,
        :cssSelectorEnabled       => true,
        :webStorageEnabled        => false,
        :rotatable                => true,
        :acceptSslCerts           => true,
        :nativeEvents             => false
      }
    }.to_json
  end

  delete "/session/:sessionId" do
    $connections.delete(params[:sessionId])
    status 204
    ''
  end

  get "/sessions" do
  end

  get "/session/:sessionId" do
  end

  # Retrieve the URL of the current page.
  get "/session/:sessionId/url" do
    puts params.inspect, "\n\n"
    puts request.body.read, "\n\n"


    status 204
    # body ''
    ''
  end

  # Navigate to a new URL.
  post "/session/:sessionId/url" do
    json = JSON(request.body.read)
    url = json['url']
    browser = $connections[params[:sessionId]][:bridge]
    browser.goto(url)

    status 204
    ''
  end

  # Refresh the current page.
  post "/session/:sessionId/refresh" do
  end

  # Inject a snippet of JavaScript into the page for execution in the context of the currently selected frame.
  post "/session/:sessionId/execute_async" do
  end

  # Take a screenshot of the current page.
  get "/session/:sessionId/screenshot" do
    conn = $connections[params[:sessionId]]
    screenshot_base64 = conn[:bridge].screenshot

    content_type :json
    {
      :status    => 0,
      :sessionId => params[:sessionId],
      :value     => screenshot_base64,
      :class     => "org.openqa.selenium.remote.Response"
    }.to_json
  end


  get "/session/:sessionId/source" do
  end

  get "/session/:sessionId/title" do
  end

  # Search for an element on the page, starting from the identified element.
  post "/session/:sessionId/element" do
  end

  # Search for multiple elements on the page, starting from the identified element.
  post "/session/:sessionId/elements" do
    conn = $connections[params[:sessionId]]
    json = JSON(request.body.read)
    elements = conn[:bridge].elements(json['using'], json['value'])

    content_type :json
    j = {
      :status    => 0,
      :sessionId => params[:sessionId],
      :value     => elements,
      :class     => "org.openqa.selenium.remote.Response"
    }.to_json
    puts j
    j
  end

  post "/session/:sessionId/element/:id/elements" do
    conn = $connections[params[:sessionId]]
    bridge = conn[:bridge]
    json = JSON.parse(request.body.read)
    elements = bridge.child_elements(params[:id], json['using'], json['value'])

    content_type :json
    {
      :status    => 0,
      :sessionId => params[:sessionId],
      :value     => elements,
      :class     => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  # Click on an element.
  post "/session/:sessionId/element/:id/click" do
    puts params.inspect, "\n\n"
    conn = $connections[params[:sessionId]]
    bridge = conn[:bridge]
    bridge.click(params[:id])

    status 204
    ''
  end


  # Submit a FORM element.
  post "/session/:sessionId/element/:id/submit" do
  end

  get "/session/:sessionId/element/:id/enabled" do
    conn = $connections[params[:sessionId]]
    bridge = conn[:bridge]
    result_value = bridge.enabled?(params[:id])

    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class     => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  # Determine if an element is currently displayed.
  get "/session/:sessionId/element/:id/displayed" do
    puts params.inspect, "\n\n"
    conn = $connections[params[:sessionId]]
    bridge = conn[:bridge]
    result_value = bridge.displayed?(params[:id])

    # {"status":0,
    # "sessionId":"31c42c95-4227-4beb-9767-5c671e605458",
    # "value":true,
    # "state":null,
    # "class":"org.openqa.selenium.remote.Response",
    # "hCode":1351626789}
    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class     => "org.openqa.selenium.remote.Response"
    }.to_json
  end


  get '/session/:sessionId/element/:id/name' do
    conn = $connections[params[:sessionId]]
    result_value = conn[:bridge].name(params[:id])

    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end


  get '/session/:sessionId/element/:id/text' do
    conn = $connections[params[:sessionId]]
    result_value = conn[:bridge].text(params[:id])

    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  get '/session/:sessionId/element/:id/attribute/:name' do
    conn = $connections[params[:sessionId]]
    result_value = conn[:bridge].attribute(params[:id], params[:name])

    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end
  # /attribute/type
  # /attribute/isContentEditable

  # Inject a snippet of JavaScript into the page for execution 
  # in the context of the currently selected frame.
  post '/session/:sessionId/execute' do
    conn = $connections[params[:sessionId]]
    json = JSON.parse(request.body.read)
    result_value = conn[:bridge].execute_json(json)
    # status 204
    # ''
    content_type :json
    {
      :status => 0,
      :sessionId => params[:sessionId],
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end


  post '/session/:sessionId/headers' do
    conn = $connections[params[:sessionId]]
    json = JSON.parse(request.body.read)
    conn[:bridge].http_headers(json['headers'])
    status 204
    ''
  end


  post '/session/:sessionId/element/:id/value' do
    conn = $connections[params[:sessionId]]
    json = JSON.parse(request.body.read)
    result_value = conn[:bridge].set_value(params[:id], json)

    status 204
    ''
  end

  get "/session/:sessionId/network_traffic" do
    $stdout.puts "\n\n**** NETWORK TRAFFIC \n\n"
    conn = $connections[params[:sessionId]]
    traffic = conn[:bridge].network_traffic

    content_type :json
    {
      :status => 0,
      :value => traffic,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  get "/session/:sessionId/cookie" do
    conn = $connections[params[:sessionId]]
    result_value = conn[:bridge].cookie

    content_type :json
    {
      :status => 0,
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  delete "/session/:sessionId/cookie" do
    conn = $connections[params[:sessionId]]
    json = JSON.parse(request.body.read)
    result_value = conn[:bridge].delete_cookie(json['name'])

    content_type :json
    {
      :status => 0,
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end

  get "/session/:sessionId/reload" do
    conn = $connections[params[:sessionId]]
    result_value = conn[:bridge].page_reload

    content_type :json
    {
      :status => 0,
      :value => result_value,
      :state => nil,
      :class => "org.openqa.selenium.remote.Response"
    }.to_json
  end
end

end
