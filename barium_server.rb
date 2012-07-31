require "sinatra"
require "sinatra/cookies"
require "uuid"
require "json"
require "securerandom"

set :public_folder, "./logs"
set :views, "./views"
SERVER_ROOT = "barium.cheezdev.com"

require "./local_override_config.rb" if File.exists? "./local_override_config.rb"

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

get "/pageview" do
  begin
    ensure_cookie()

    page_viewed_event = PageViewedEvent.new
    page_viewed_event.current_time = Time.now
    page_viewed_event.persistent_id = cookies[:barium_trace]
    page_viewed_event.referer = request.referer
    page_viewed_event.user_agent = request.user_agent
    page_viewed_event.pageview_id = params[:pageview_id]
    page_viewed_event.project_name = params[:project_name]
    page_viewed_event.site_id = params[:site_id]

    log page_viewed_event, current_log_file_path
  rescue Exception => error
    return "// Current directory: #{Dir.getwd}<br/>#{error.message}<br/> #{error.backtrace}"
  end
end

get "/log_event" do
  if params[:command_name] == "split_test_event"
    split_test_event = SplitTestEvent.new
    split_test_event.current_time = Time.now
    split_test_event.persistent_id = params[:user_id]
    split_test_event.user_agent = request.user_agent
    split_test_event.url = request.referer
    split_test_event.test_name = params[:test_name]
    split_test_event.segment_name = params[:segment_name]
    split_test_event.event_name = params[:event_name]

    log split_test_event, current_split_test_event_log_file_path
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
  custom_event.url = request.referer
  custom_event.pageview_id = params[:pageview_id]
  custom_event.project_name = params[:project_name]
  custom_event.site_id = params[:site_id]
  custom_event.user_agent = request.user_agent

  log custom_event, current_log_file_path
end

get "/clean" do
  puts "Current File: " + current_log_file_path
  Dir.glob("#{log_folder_path}/*") do |file_path|
    File.delete(file_path) unless file_path == current_log_file_path or file_path == current_error_log_file_path or file_path == current_split_test_event_log_file_path
  end
  "Cleaned all log files prior to #{current_log_file_path}"
end

get "/files_to_archive" do
  log_files = Dir.glob("#{log_folder_path}/*")
                .reject{|file_path| file_path.include? current_time_partial_file_name}
                .reject{|file_path| file_path.include? current_split_test_event_log_file_path} 
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
  response['Cache-Control'] = "no-store, no-cache, must-revalidate"
  response['Expires'] = "-1"

  erb :barium_js
end

def log_folder_path
  log_folder_path = "./logs"
end

def date_pad value
  return value if value == nil
  '0' * (2 - value.to_s.length) + value.to_s
end

def current_split_test_event_log_file_path
  current_time = Time.now
  month = date_pad current_time.month
  day = date_pad current_time.day
  hour = date_pad current_time.hour
  "#{log_folder_path}/#{current_time.year}_#{month}_#{day}_#{hour}_splittests.txt"
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

def replace_bad_characters_from provided_string
  if provided_string != nil
    return provided_string.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'")
  else
    return provided_string
  end
end

class SplitTestEvent
  attr_accessor :current_time, :persistent_id, :user_agent, :url, :test_name, :segment_name, :event_name

  def write_to thing
    @persistent_id = replace_bad_characters_from @persistent_id
    @user_agent = replace_bad_characters_from @user_agent
    @test_name = replace_bad_characters_from @test_name
    @segment_name = replace_bad_characters_from @segment_name
    @event_name = replace_bad_characters_from @event_name
    @url = replace_bad_characters_from @url
    @user_agent = @user_agent.gsub(/[\"]+/, "'") if @user_agent != nil

    thing.puts "split_test_event\t#{@current_time}\t#{@persistent_id}\t#{@user_agent}\t#{@url}\t#{@test_name}\t#{@segment_name}\t#{@event_name}"
  end
end

class CustomEvent
  attr_accessor :category, :action, :label, :value, :current_time, :persistent_id, :url, :pageview_id, :project_name, :site_id, :user_agent
  def write_to thing
    @category = @category.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @category != nil;
    @action = @action.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @action != nil;
    @label = @label.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @label != nil;
    @value = @value.gsub(/[\n\t]+/, " ").gsub(/[\"]+/, "'") if @value != nil;
    @url = @url.gsub(/[\"]+/, "'") if @url != nil
    @user_agent = @user_agent.gsub(/[\"]+/, "'") if @user_agent != nil
    thing.puts "custom_event\t#{@current_time}\t#{@persistent_id}\t#{@category}\t#{@action}\t#{@label}\t#{@value}\t#{@url}\t#{pageview_id}\t#{@project_name}\t#{@site_id}\t#{@user_agent}"
  end
end

class PageViewedEvent
  attr_accessor :current_time, :persistent_id, :referer, :user_agent, :pageview_id, :project_name, :site_id
  def write_to thing
    @user_agent = @user_agent.gsub(/[\"]+/, "'") if @user_agent != nil
    @referer = @referer.gsub(/[\"]+/, "'") if @referer != nil
    thing.puts "page_view\t#{@current_time}\t#{@persistent_id}\t#{@referer}\t#{@user_agent}\t#{@pageview_id}\t#{@project_name}\t#{@site_id}"
  end
end