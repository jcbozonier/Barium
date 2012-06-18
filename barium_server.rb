require "sinatra"
require "sinatra/cookies"
require "uuid"
require "json"
require "securerandom"

set :public_folder, "./logs"
set :views, "./views"
SERVER_ROOT = "127.0.0.1:9292"
#SERVER_ROOT = "barium.cheezdev.com"

error do
  puts 'your mom down'
 error_event = ErrorEvent.new
 error_event.current_time = Time.now
 error_event.persistent_id = cookies[:barium_trace]
 error_event.user_agent = request.user_agent
 error_event.referer = request.referer
 
 sinatra_error = request.env['sinatra.error']
 error_event.error = sinatra_error.message + "\n" + sinatra_error.backtrace.join("\n")
 
 log error_event, current_error_log_file_path
 
 'SOMETHING ASPLODED!'
end

get "/asplode" do
  raise Error, "I ASPLODED!"
end

get "/test_client" do
  @server_root = SERVER_ROOT
  erb :test_client
end

get "/never_end" do
  while true do
    nil
  end
end

get "/new_event/v2" do
  ensure_cookie()
  custom_event = CustomEvent.new
  custom_event.current_time = Time.now
  custom_event.persistent_id = cookies[:barium_trace]
  
  custom_event.category = params[:category]
  custom_event.action = params[:action]
  custom_event.label = params[:label]
  custom_event.value = params[:value]

  log custom_event, current_log_file_path
end

get "/new_event" do
  puts "Tracking custom event"
  ensure_cookie()
  event = JSON.parse(params[:event])
  custom_event = CustomEvent.new
  custom_event.current_time = Time.now
  custom_event.persistent_id = cookies[:barium_trace]
  
  custom_event.category = event[0]
  custom_event.action = event[1] unless event.length < 2
  custom_event.label = event[2] unless event.length < 3
  custom_event.value = event[3] unless event.length < 4

  log custom_event, current_log_file_path
end

get "/clean" do
  puts "Current File: " + current_log_file_path
  Dir.glob("#{log_folder_path}/*") do |file_path|
    File.delete(file_path) unless file_path == current_log_file_path or file_path == current_error_log_file_path
  end
  "Cleaned all log files prior to #{current_log_file_path}"
end

get "/files_to_archive" do
  log_files = Dir.glob("#{log_folder_path}/*")
                .reject{|file_path| file_path.include? current_time_partial_file_name}
                .map { |file_path| { 
                    "uri" => File.join("http://", "#{request.host}:#{request.port}", File.basename(file_path)), 
                    "size" => File.size(file_path) 
                  } 
                }

  log_files.to_json
end

get "/log_directory" do
  @log_files = Dir.glob("#{log_folder_path}/*").map do |file_path|
    File.basename(file_path)
  end
  erb :log_directory
end

get "/my_pid" do
  "Your cookie is #{cookies[:barium_trace]}"
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

    log page_viewed_event, current_log_file_path

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
  "#{log_folder_path}/log_#{current_time_partial_file_name}.txt"
end

def current_error_log_file_path
  "#{log_folder_path}/errors_#{current_time_partial_file_name}.txt"
end

def current_time_partial_file_name
  current_time = Time.now
  "#{current_time.year}_#{current_time.month}_#{current_time.day}_#{current_time.hour}"
end

def log event, path
  if not File.directory?(log_folder_path)
    Dir.mkdir log_folder_path
  end
  (file = File.new(path,'a')).flock(File::LOCK_EX)

  event.write_to file

  file.flock(File::LOCK_UN)
  file.close
end

def ensure_cookie
  if cookies[:barium_trace] == nil
    puts "No cookie! Setting..."
    response.set_cookie("barium_trace",
                        :value => SecureRandom.uuid,
                        :domain => @server_root,
                        :path => "/",
                        :expires => Time.new(Time.now.year + 20,1,1))
    puts "Set the cookie!"
  else
    puts "Found cookie! Here: #{cookies[:barium_trace]}"
  end
end

class ErrorEvent
  attr_accessor :current_time,:persistent_id, :error, :user_agent, :referer
  def write_to thing
    thing.puts "error\t#{current_time}\t#{persistent_id}\t#{user_agent}\t#{referer}\t#{error}"
  end
end

class CustomEvent
  attr_accessor :category, :action, :label, :value, :current_time, :persistent_id
  def write_to thing
    @category = @category.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @category != nil;
    @action = @action.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @action != nil;
    @label = @label.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @label != nil;
    @value = @value.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @value != nil;
    thing.puts "custom_event\t#{@current_time}\t#{@persistent_id}\t#{@category}\t#{@action}\t#{@label}\t#{@value}"
  end
end

class PageViewedEvent
  attr_accessor :current_time, :persistent_id, :referer, :user_agent
  def write_to thing
    @user_agent = @user_agent.gsub(/[\"]+/, "'") if @user_agent != nil
    @referer = @referer.gsub(/[\"]+/, "'") if @referer != nil
    thing.puts "page_view\t#{@current_time}\t#{@persistent_id}\t#{@referer}\t#{@user_agent}"
  end
end