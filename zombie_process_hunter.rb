require 'daemons'

root_directory = File.join(Dir.pwd, "logs") 

Daemons.run_proc 'zombie_process_hunter.rb' do
  loop do
    begin
      lines = `ps aux -ww | awk '{ print $11 " " $2 " " $3 " " $4 }'`.split("\n")
      lines.each do |line|
        _not_used, pid, cpu, usage = line.split(' ').map &:to_i
        if cpu > 5
          current_time = Time.now
          suspected_zombie_file_name = "suspected_zombies_#{current_time.year}_#{current_time.month}_#{current_time.day}_#{current_time.hour}.txt"
          suspected_zombie_log_file_path = File.join("#{root_directory}", suspected_zombie_file_name)
          open(suspected_zombie_log_file_path, 'a') do |f|
            timestamp = Time.now.localtime.strftime '%D %r'
            f.puts "#{timestamp}\t#{pid}\t#{line}"
          end 
        end
      end
    rescue
      zombie_error_file_name = "zombie_error_#{current_time.year}_#{current_time.month}_#{current_time.day}_#{current_time.hour}.txt"
      zombie_error_file_path = File.join(root_directory, zombie_error_file_name)
      open(zombie_error_file_path, 'a') do |f|
      f.puts $!
    end
      end
    sleep 60
  end
end