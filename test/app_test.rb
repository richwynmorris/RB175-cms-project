ENV['RACK_ENV'] = "test" #prevents sinatra from starting a web server when testing

require 'minitest/autorun'
require 'rack/test'
require "fileutils"

require_relative '../app.rb'

class AppTest < Minitest::Test
  include Rack::Test::Methods # mixing in methods from rack-test

  def app
    Sinatra::Application # mixed in methods from Rack expect to have the method app defined with reference to the application we're running
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end


  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_updating_document
    create_document "changes.txt"

    post "/changes.txt", new_text: "new content"

    assert_equal 302, last_response.status

    assert_equal "The contents of changes.txt have been updated.", session[:success]

    get last_response["Location"]
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal last_response.body, "new content"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete"

    assert_equal 302, last_response.status

    assert_equal "'test.txt' has been deleted.", session[:success]
    get last_response["Location"]
    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_signin_form
    get "/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, 'input type="submit" value="Sign In"'
  end

  def test_signin
    post "/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    
    assert_equal "Welcome Admin", session[:success]
    assert_equal  "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin", user: "admin" } }
    assert_equal "admin", session[:username]
    assert_includes last_response.body, "Signed in as admin"

    post "/signout"
    assert_equal "You have been signed out", session[:message]
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def admin_session
    { "rack.session" => { username: "admin", user: 'admin' } }
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_updating_document
    create_document "changes.txt"

    post "/changes.txt", {new_text: "new content"}, admin_session

    assert_equal "changes.txt has been updated.", session[:success]
    assert_equal 302, last_response.status

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    post "/changes.txt", {new_text: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_view_new_document_form
    get "/new/document", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_new_document
    post "/new/document", {doc: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'test.txt' has been created.", session[:success]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_signed_out
    post "/new/document", {doc: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_new_document_without_filename
    post "/new/document", {doc: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'test.txt' has been deleted.", session[:success]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_deleting_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end
end