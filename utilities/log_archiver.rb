require 'httparty'
require 'JSON'

def archive_files
	#server_root = "127.0.0.1:9292"
	
	log_directory = "c:/Barium"
	server_index = 0
	servers = ['ec2-50-19-179-243.compute-1.amazonaws.com', 'ec2-107-21-85-95.compute-1.amazonaws.com']
	servers.each do |server_root|
		puts "archiving from server #{server_root}"
		json_files_to_archive = HTTParty.get("http://#{server_root}/files_to_archive")
		files_to_archive = JSON.parse(json_files_to_archive)

		all_files_downloaded_correctly = true

		Dir.mkdir log_directory unless File.directory? log_directory

		files_to_archive.each do |file_to_archive|
			file_name = server_index.to_s + "_" + File.basename(file_to_archive["uri"])
			puts "Starting log file download for #{file_name}"
			log_file_path = File.join(log_directory, file_name)

			if File.exists?(log_file_path) and files_match File.size(log_file_path), file_to_archive["size"]
				puts "skipping download #BecauseRacecar"
				next
			end
			
			log_file_text = HTTParty.get(file_to_archive["uri"])

			File.open(log_file_path, "w") do |file|
				file.write log_file_text
			end
			if files_match File.size(log_file_path), file_to_archive["size"]
				puts "log download success!" 
			else
				puts "log download FAIL! local #{File.size(log_file_path)} vs server #{file_to_archive["size"]}" 
				all_files_downloaded_correctly = false
			end
		end
		
		if all_files_downloaded_correctly
			puts "Cleaning out the archived log files!"
			HTTParty.get("http://#{server_root}/clean") 
		else 
			puts "Shit went sour! Not clearing the logs."
		end
		
		server_index += 1
	end
end

def files_match local_file_size, server_file_size
	file_size_ratio = server_file_size.to_f / local_file_size.to_f
	puts "Ratio is #{file_size_ratio}"
	return file_size_ratio >= 0.9891 # Different file systems, different file sizes
end

archive_files