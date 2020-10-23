require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set session_secret: "my secret"
end

before do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def valid_file_name?(file)
  @files.include?(file)
end

def get_file_path(params)
  file_path = File.join(data_path, params) # Assigns the variable of `file_path` with the directory of the requested file
end

def check_file_exits(file)
    valid_file = valid_file_name?(file) # Check to see is the param is included in the files array

    if valid_file && signed_in_user?
      load_up_file_by_ext(file)
    elsif !signed_in_user?
      must_be_signed_in_response 
    else
      session[:error] = "#{params[:filename]} does not exist" # assigns error message to the session variable
      redirect '/'
    end
end

def load_up_file_by_ext(params)
    file_path = get_file_path(params)
    text = File.read(file_path) # Read method opens the file and returns the contents of the file as a string

    if File.extname(file_path) == ".txt"    
      headers["Content-Type"] = "text/plain" # header tells the browser to display the content of the file as a plain text file.
      File.read(file_path)
    elsif File.extname(file_path) == '.md'
      erb render_markdown(text)
    end
end

def valid_new_file?(name)
  !name.chars.all?(' ') && name.include?('.txt') || name.include?('.md')
end

def signed_in_user?
  session[:user] == 'admin'
end

def must_be_signed_in_response
  session[:error] = "You must be signed in to do that."
  redirect '/'
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

get "/" do
  erb :list , layout: :layout
end

get "/signin" do
  erb :sign_in, layout: :layout
end

post "/signin" do
  if valid_credentials?(params[:username], params[:password])
    session[:user] = params[:username]
    session[:success] = "Welcome #{session[:user].capitalize}"
    redirect '/'
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :sign_in, layout: :layout
  end
end

post "/signout" do
  session.delete(:user) && session.delete(:username) 
  session[:message] = "You have been signed out"
  redirect '/signin'
end

get "/:filename" do
  check_file_exits(params[:filename])
end

get "/:filename/edit" do
  if signed_in_user?
    @file = params[:filename]
    file_path = get_file_path(@file)
    @contents = File.read(file_path)
    erb :edit , layout: :layout
  else
    must_be_signed_in_response
  end
end

post "/:filename" do
  if signed_in_user?
    content = params[:new_text]
    file_path = get_file_path(params[:filename]) # get_file_path(params[:filename])
    File.open(file_path, "r+") {|f| f.write(content) }
    session[:success] = "#{params[:filename]} has been updated."
    redirect '/'
  else
    must_be_signed_in_response
  end
end

get "/new/document" do
  if signed_in_user?
    erb :new_doc, layout: :layout
  else
    must_be_signed_in_response
  end
end

post "/new/document" do
  file = params[:doc]

  if signed_in_user? && valid_new_file?(file)
    file_path = get_file_path(file)
    File.write(file_path, "Get started..")
    session[:success] = "'#{params[:doc]}' has been created."
    redirect '/'
  elsif signed_in_user? && !valid_new_file?(file)
    session[:error] = "A name is required. Must be a .txt or .md file"
    status 422
    erb :new_doc, layout: :layout
  else
    must_be_signed_in_response
  end
end

post "/:filename/delete" do
  if signed_in_user?
    file_path = get_file_path(params[:filename])
    File.delete(file_path)
    session[:success] = "'#{params[:filename]}' has been deleted."
    redirect '/'
  else
    must_be_signed_in_response
  end
end

