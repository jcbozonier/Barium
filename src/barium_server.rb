require "sinatra"
require "sinatra/cookies"
require "uuid"

set :public_folder, "./logs"

get "/" do
  begin
    puts "Starting to track"
    if cookies[:barium_trace] == nil
        puts "No cookie! Setting..."
        response.set_cookie("barium_trace",
                   :value => UUID.generate(),
                   :domain => 'LogBalancer-231309745.us-east-1.elb.amazonaws.com',
                   :path => "/",
                   :expires => Time.new(2020,1,1))
        puts "Set the cookie!"
    else
      puts "Found cookie! Here: #{cookies[:barium_trace]}"
    end

    current_time = Time.now
    log_folder_path = "./logs"
    log_file_path = "#{log_folder_path}/log_#{current_time.hour}.txt"

    if not File.directory?(log_folder_path)
      Dir.mkdir log_folder_path
    end

    trace_id = cookies[:barium_trace]

    (file = File.new(log_file_path,'a')).flock(File::LOCK_EX)
    file.puts("#{current_time}\t#{trace_id}")
    file.flock(File::LOCK_UN)
    file.close

    puts "Ending tracking"
  rescue Exception => error
    return "// Current directory: #{Dir.getwd}<br/>#{error.message}<br/> #{error.backtrace}"
  end

  response['Cache-Control'] = "no-cache"
  response['Expires'] = "-1"
  "function barium_loaded(){};"
end