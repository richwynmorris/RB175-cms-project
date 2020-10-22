ENV['RACK_ENV'] = "test" #prevents sinatra from starting a web server when testing

require 'minitest/autorun'
require 'rack/test'

require_relative '../app.rb'

class AppTest < Minitest::Test
  include Rack::Test::Methods # mixing in methods from rack-test

  def app
    Sinatra::Application # mixed in methods from Rack expect to have the method app defined with reference to the application we're running
  end

  def test_valid_response
    get "/"

    assert_equal 200, last_response.status # last_response returns an instance of Rack::MockResponse. Provides methods for status, body and []
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_file_content
    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "talking with my colleague"
  end

  def test_invalid_file
    get "/notafile.ext"

    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get "/" 
    refute_includes last_response.body, "notafile.ext does not exist"
  end
end