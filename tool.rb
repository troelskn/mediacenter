$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'models'

streams = Streams.new(File.join(File.dirname(__FILE__), "streams"))
streams.all.each do |s|
  puts "#{s.id} #{s.status} #{s.title}"
end
