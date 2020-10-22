require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set session_secret: "my secret"
end

ROOT = File.expand_path("..", __FILE__) # references the absolute path of the file that references the `__FILE__` keyword

before do
  @files = Dir.glob(ROOT + "/data/*").map do |path|
    File.basename(path)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def valid_file_name?(file)
  @files.include?(file)
end

def load_up_file_by_ext(params)
    file_path = ROOT + "/data/" + params # Assigns the variable of `file_path` with the directory of the requested file
    text = File.read(file_path) # Read method opens the file and returns the contents of the file as a string
    if File.extname(file_path) == ".txt"    
      headers["Content-Type"] = "text/plain" # header tells the browser to display the content of the file as a plain text file.
      File.read(file_path)
    elsif File.extname(file_path) == '.md'
      render_markdown(text)
    end
end

get "/" do
  erb :list
end

get "/:filename" do
  valid_file = valid_file_name?(params[:filename]) # Check to see is the param is includes in the files array

  if valid_file
    load_up_file_by_ext(params[:filename])
  else
    session[:error] = "#{params[:filename]} does not exist" # assigns error message to the session variable
    redirect '/'
  end
end