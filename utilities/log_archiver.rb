require 'httparty'
require 'JSON'

server_root = "127.0.0.1:9292"
log_directory = "./"

json_files_to_archive = HTTParty.get("http://#{server_root}/files_to_archive")
files_to_archive = JSON.parse(json_files_to_archive)

all_files_downloaded_correctly = true

Dir.mkdir log_directory unless File.directory? log_directory

files_to_archive.each do |file_to_archive|
	file_name = File.basename file_to_archive["uri"]
	log_file_text = HTTParty.get(file_to_archive["uri"])
	log_file_path = File.join(log_directory, file_name)

	if File.exists?(log_file_path) and File.size(log_file_path) == file_to_archive["size"]
		puts "skipping #BecauseWonderful"
		next
	end

	File.open(log_file_path, "w") do |file|
		file.write log_file_text
	end
	if File.size(log_file_path) == file_to_archive["size"]
		puts "log download success!" 
	else
		all_files_downloaded_correctly = false
	end
end

HTTParty.get("http://#{server_root}/clean") if all_files_downloaded_correctly