require 'thin'
require 'sinatra'
require 'sinatra/contrib'
require 'securerandom'
require 'json'
require 'active_support'
require 'active_support/hash_with_indifferent_access'
require 'net/http'
require File.expand_path(File.dirname(__FILE__)) + "/bridge.rb"


class SeleniumServer < Sinatra::Base
  register Sinatra::Namespace

  set :server,  'thin'
  set :port,    4444
  set :bind,    '0.0.0.0'

  $connections = {}

  helpers do
    def conn
      conn = $connections[params[:sessionId]]
    end

    def json_body
      begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError => e
        $stdout.puts "* Failed to parse JSON from request.body"
        nil
      end
    end

    def result_response(type=nil, &block)
      result_value = nil
      json = json_body
      result_value = block.call(conn[:bridge], json)

      if type == :json
        content_type :json
        {
          :status => 0,
          :value => result_value,
          :state => nil,
          :class => "org.openqa.selenium.remote.Response"
        }.to_json
      else
        status 204
        ''
      end
    end
  end

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

      $connections[_uuid_][:bridge] = Server::Bridge.new(websocket_uri)

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
      result_response :json do |bridge|
        bridge.current_url
      end
    end

    # Navigate to a new URL.
    post "/session/:sessionId/url" do
      result_response do |bridge, json|
        bridge.goto(json['url'])
      end
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
      result_response :json do |bridge, json|
        bridge.elements(json['using'], json['value'])
      end
    end

    post "/session/:sessionId/element/:id/elements" do
      result_response :json do |bridge, json|
        bridge.child_elements(params[:id], json['using'], json['value'])
      end
    end

    # Click on an element.
    post "/session/:sessionId/element/:id/click" do
      result_response do |bridge, json|
        bridge.click(params[:id])
      end
    end


    # Submit a FORM element.
    post "/session/:sessionId/element/:id/submit" do
    end

    get "/session/:sessionId/element/:id/enabled" do
      result_response :json do |bridge, json|
        bridge.enabled?(params[:id])
      end
    end

    # Determine if an element is currently displayed.
    get "/session/:sessionId/element/:id/displayed" do
      result_response :json do |bridge, json|
        bridge.displayed?(params[:id])
      end
    end


    get '/session/:sessionId/element/:id/name' do
      result_response :json do |bridge, json|
        bridge.name(params[:id])
      end
    end


    get '/session/:sessionId/element/:id/text' do
      result_response :json do |bridge, json|
        bridge.text(params[:id])
      end
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
      result_response :json do |bridge, json|
        bridge.delete_cookie(json['name']) if json
      end
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
