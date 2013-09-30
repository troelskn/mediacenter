$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'models'

def streams
  @streams ||= Streams.new(File.join(File.dirname(__FILE__), "streams"))
end

namespace :streams do
  namespace :list do
    desc "List all streams"
    task :all do
      streams.all.each do |s|
        puts "#{s.id} #{s.status} #{s.title}"
      end
    end

    desc "List streams with status deleted"
    task :deleted do
      streams.all.select{|s| s.status == "deleted" }.each do |s|
        puts "#{s.id} #{s.status} #{s.title}"
      end
    end

    desc "List streams with status encoding"
    task :encoding do
      streams.all.select{|s| s.status == "encoding" }.each do |s|
        puts "#{s.id} #{s.status} #{s.title}"
      end
    end
  end

  desc "Restart encoding. Call as streams:restart[SHA]"
  task :restart, :sha do |t, args|
    s = streams.all.select{|s| s.id == args[:sha] }.first
    streams.save! s, "initial"
    command = "rm #{s.data_folder_path}/*"
    puts command
    `#{command}`
  end
end
