require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_homephone(homephone)
  phone_num = homephone.tr('()-. ', '')
  case phone_num.length
  when 10
    phone_num
  when 11
    phone_num[0] == '1' ? phone_num[1..-1] : nil
  else
    nil
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_peak_hours(hour_count)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = 'output/peak_hours.csv'
  File.open(filename, 'w') do |file|
    peak_hours = hour_count.sort_by{ |_, v| -v }.to_h
    file.puts 'Time, Count'
    peak_hours.each do |hour, count|
      time12h = Time.strptime(hour.to_s, '%k').strftime('%r')
      file.puts "#{time12h}, #{count}"
    end
  end
end

def save_peak_weekdays(weekday_count)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = 'output/peak_weekdays.csv'
  File.open(filename, 'w') do |file|
    peak_weekdays = weekday_count.sort_by{ |_, v| -v }.to_h
    file.puts 'Weekday, Count'
    peak_weekdays.each do |wday, count|
      weekday = Date::DAYNAMES[wday]
      file.puts "#{weekday}, #{count}"
    end
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hour_count = Hash.new(0)
weekday_count = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  
  homephone = clean_homephone(row[:homephone])

  time = Time.strptime(row[:regdate], '%m/%e/%y %k:%M')
  hour_count[time.hour] += 1
  weekday_count[time.wday] += 1

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id,form_letter)
end

save_peak_hours(hour_count)
save_peak_weekdays(weekday_count)
