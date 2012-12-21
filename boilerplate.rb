require 'singleton'

# http://rubydoc.info/gems/wait_for/frames
def wait_for(options = {}, &block)
  puts "Waiting .. "
  options = {:timeout => 10, :frequency => 0.1}.merge(options)
  return_val = nil
  Timeout.timeout(options[:timeout]) {
    while (return_val = block.call).nil?
      sleep(options[:frequency])
    end
  }
  puts "Done."
  return_val
end

# http://ruhe.tumblr.com/post/565540643/generate-json-from-ruby-struct
class Struct
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    self.to_map.to_json(*a)
  end
end

class Globals < Hash
  include Singleton
  def self.method_missing(m, *args)
    if m[-1..-1] == '='
      self.instance[m[0..-2].to_sym] = args.first
    else
      self.instance[m.to_sym]
    end
  end
end
