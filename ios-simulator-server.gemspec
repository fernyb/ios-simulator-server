# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ios/simulator/server/version'

Gem::Specification.new do |spec|
  spec.name          = "ios-simulator-server"
  spec.version       = Ios::Simulator::Server::VERSION
  spec.authors       = ["Fernando Barajas"]
  spec.email         = ["fb2114@yp.com"]
  spec.summary       = %q{A Selenium Server for iOS Simulator only}
  spec.description   = %q{A Selenium Server for iOS Simulator only}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  #spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.executables = ['ios-simulator-server']
  spec.default_executable = 'ios-simulator-server'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency "selenium-webdriver"
  spec.add_runtime_dependency "thin"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "sinatra"
  spec.add_runtime_dependency "sinatra-contrib"
  spec.add_runtime_dependency "websocket"
end
