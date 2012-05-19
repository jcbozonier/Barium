require 'CSV'
require 'time'
require 'json'
require 'bloomfilter-rb'

days = {}
users = {}

start_time = Time.now

users_who_voted = BloomFilter::Native.new(:size=>100000000, :hashes=>5, :seed=>Random.rand(999999)+1, :bucket=>3)

Dir.glob("c:/Barium/*")
	.reject{|log_file| log_file.include? "errors_"}
	.each do |log_file|
		puts "Begin processing #{log_file}"
		
		CSV.foreach(log_file, {:col_sep=>"\t"}) do |row| 
			event_type = row[0].strip
			category = ""
			category = row[3].strip if event_type == "custom_event" && row[3] != nil
			datetime = Time.parse(row[1])
			date = "#{datetime.year}/#{datetime.month}/#{datetime.day}"
			current_pid = row[2].strip
			
			if not users.has_key?(current_pid)
				users[current_pid] = true
			end
			
			if not days.has_key?(date)
				days[date] = BloomFilter::Native.new(:size=>100000000, :hashes=>5, :seed=>Random.rand(999999)+1, :bucket=>3)
			end
			
			if event_type == "custom_event" and category == "voting"
				users_who_voted.insert current_pid
			end
			
			days[date].insert current_pid
		end
		
		puts "Done processing #{log_file}"
	end

preprocessing_stop_time = Time.now
puts "Preprocessing started at #{start_time} and stopped at #{preprocessing_stop_time}"
puts "Now reporting..."
# Total number of users
# Number of users who returned to the site
# Number of users who voted
# Number of users who voted AND returned to the site

total_number_of_users = users.keys.length
number_of_users_who_return = 0
number_of_users_who_voted = 0
number_of_users_who_voted_and_returned = 0

users.each do |pid, user_info|
	user_returned_at_least_once = true if 2 <= days.inject(0){|sum, tuple| 
		if tuple[1].include? pid
			sum + 1 
		else
			sum
		end
	}
	user_voted = users_who_voted.include? pid
	
	if user_returned_at_least_once
		number_of_users_who_return += 1 
	end
	
	if user_voted
		number_of_users_who_voted += 1
	end
	
	if user_returned_at_least_once and user_voted
		number_of_users_who_voted_and_returned += 1
	end
end



puts "Total number of users: #{total_number_of_users}"
puts "Number of users who return: #{number_of_users_who_return}"
puts "Number of users who voted: #{number_of_users_who_voted}"
puts "Number of users who voted and returned: #{number_of_users_who_voted_and_returned}"
puts "~~~~~~~~"
#puts "Users who voted bloom filter stats:"
#users_who_voted.stats
#puts "Users who returned bloom filter stats:"
#puts days.each{|date, day| day.stats}
puts "~~~~~~~~"
puts "Of #{total_number_of_users} total users there were #{number_of_users_who_voted} voters"
puts "#{100*number_of_users_who_voted.to_f/total_number_of_users.to_f}% were voters"


stop_time = Time.now

puts "Started at #{start_time} and stopped at #{stop_time}"