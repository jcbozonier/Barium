require 'CSV'
require 'time'
require 'json'
require 'bloom-filter'

class VisitorDaysHash
  def initialize
    @bloom_filter = BloomFilter.new(size: 60000000, error_rate: 0.001)
    @days_list = {}
  end
  
  def insert date, pid
    @days_list[date] = true
    @bloom_filter.insert date + "_" + pid
  end
  
  def include? date, pid
    @bloom_filter.include? date + "_" + pid
  end
  
  def returned_at_least_once pid
    number_of_days_returned = @days_list.keys.inject(0) do |sum, date| 
      if self.include? date, pid
        1 + sum
      else
        sum
      end
    end
    
    return number_of_days_returned >= 2
  end
end

users_filter = BloomFilter.new(size: 30000000, error_rate: 0.001)
users_who_voted = BloomFilter.new(size: 10000000, error_rate: 0.001)
start_time = Time.now
visitor_days_hash = VisitorDaysHash.new

File.open("distinct_user_list.temp", 'w') do |distinct_users_file| 
  Dir.glob("c:/Barium/*")
	.reject{|log_file| log_file.include? "errors_"}#.reject{|log_file| not log_file.include?("1_log_2012_5_")}
	.each do |log_file|
    #line_number = 0
		puts "Begin processing #{log_file}"
		date = nil
		CSV.foreach(log_file, {:col_sep=>"\t"}) do |row| 
      #line_number += 1
      #puts line_number.to_s + " " + log_file
			datetime = Time.parse(row[1])
			date = "#{datetime.year}/#{datetime.month}/#{datetime.day}"
			event_type = row[0].strip
			category = ""
			category = row[3].strip if event_type == "custom_event" && row[3] != nil
			current_pid = row[2].strip
			
			if not users_filter.include?(current_pid)
				users_filter.insert current_pid
				distinct_users_file.puts current_pid
			end
			
			if event_type == "custom_event" and category == "voting"
				users_who_voted.insert current_pid
			end
			
      visitor_days_hash.insert date, current_pid
		end
		
		puts "Done processing #{log_file}"
	end
end
preprocessing_stop_time = Time.now
puts "Preprocessing started at #{start_time} and stopped at #{preprocessing_stop_time}"
puts "Now reporting..."

total_number_of_users = 0
number_of_users_who_return = 0
number_of_users_who_voted = 0
number_of_users_who_voted_and_returned = 0

File.open("distinct_user_list.temp", 'r') do |distinct_users_file|
  distinct_users_file.each_line do |pid|
    total_number_of_users += 1
    user_returned_at_least_once = true if visitor_days_hash.returned_at_least_once pid.strip
    user_voted = users_who_voted.include? pid.strip
    
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
end


puts "Total number of users: #{total_number_of_users}"
puts "Number of users who return: #{number_of_users_who_return}"
puts "Number of users who voted: #{number_of_users_who_voted}"
puts "Number of users who voted and returned: #{number_of_users_who_voted_and_returned}"
puts "~~~~~~~~"
puts "~~~~~~~~"
puts "Of #{total_number_of_users} total users there were #{number_of_users_who_voted} voters"
puts "#{100*number_of_users_who_voted.to_f/total_number_of_users.to_f}% were voters"


stop_time = Time.now

puts "Started at #{start_time} and stopped at #{stop_time}"