require "sinatra"
require "sinatra/cookies"
require "uuid"
require "json"

set :public_folder, "./logs"
set :views, "./views"
#SERVER_ROOT = "127.0.0.1:9292"
SERVER_ROOT = "LogBalancer-231309745.us-east-1.elb.amazonaws.com"

get "/test_client" do
  @server_root = SERVER_ROOT
  erb :test_client
end

get "/new_event" do
  puts "Tracking custom event"
  ensure_cookie()
  event = JSON.parse(params[:event])
  custom_event = CustomEvent.new
  custom_event.current_time = Time.now
  custom_event.persistent_id = cookies[:barium_trace]
  custom_event.category = event[0]
  custom_event.action = event[1]
  custom_event.label = event[2]

  log custom_event
end

get "/clean" do
  puts "Current File: " + current_log_file_path
  Dir.glob("#{log_folder_path}/*") do |file_path|
    File.delete(file_path) unless file_path == current_log_file_path 
  end
  "Cleaned all log files prior to #{current_log_file_path}"
end

get "/log_directory" do
  @log_files = Dir.glob("#{log_folder_path}/*").map do |file_path|
    File.basename(file_path)
  end
  erb :log_directory
end

get "/" do
  @server_root = SERVER_ROOT
  begin
    puts "Starting to track"
    ensure_cookie()

    page_viewed_event = PageViewedEvent.new
    page_viewed_event.current_time = Time.now
    page_viewed_event.persistent_id = cookies[:barium_trace]
    page_viewed_event.referer = request.referer
    page_viewed_event.user_agent = request.user_agent

    log page_viewed_event

    puts "Ending tracking"
  rescue Exception => error
    return "// Current directory: #{Dir.getwd}<br/>#{error.message}<br/> #{error.backtrace}"
  end

  response['Cache-Control'] = "no-store, no-cache, must-revalidate"
  response['Expires'] = "-1"

  erb :barium_js
end

def log_folder_path
  log_folder_path = "./logs"
end

def current_log_file_path
  current_time = Time.now
  "#{log_folder_path}/log_#{current_time.year}_#{current_time.month}_#{current_time.day}_#{current_time.hour}.txt"
end

def log event
  if not File.directory?(log_folder_path)
    Dir.mkdir log_folder_path
  end

  (file = File.new(current_log_file_path,'a')).flock(File::LOCK_EX)

  event.write_to file

  file.flock(File::LOCK_UN)
  file.close
end

def ensure_cookie
  if cookies[:barium_trace] == nil
    puts "No cookie! Setting..."
    response.set_cookie("barium_trace",
                        :value => UUID.generate(),
                        :domain => @server_root,
                        :path => "/",
                        :expires => Time.new(Time.now.year + 20,1,1))
    puts "Set the cookie!"
  else
    puts "Found cookie! Here: #{cookies[:barium_trace]}"
  end
end

class CustomEvent
  attr_accessor :category, :action, :label, :current_time, :persistent_id
  def write_to thing
    thing.puts "custom_event\t#{@current_time}\t#{@persistent_id}\t#{@category}\t#{@action}\t#{@label}"
  end
end

class PageViewedEvent
  attr_accessor :current_time, :persistent_id, :referer, :user_agent
  def write_to thing
    thing.puts "page_view\t#{@current_time}\t#{@persistent_id}\t#{@referer}\t#{@user_agent}"
  end
end