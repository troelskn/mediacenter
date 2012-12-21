require 'pathname'

module FFmpeg
  class ProbeResult < Struct.new(:path, :duration, :title)
    def name
      self.title || (self.path.dirname.basename.to_s + "/" + self.path.basename.to_s)
    end
  end

  def self.probe(path)
    probe = `ffprobe "#{path}" 2>&1`
    duration = probe.match(/Duration: ([^.]*)/)
    title = probe.match(/title\s+: (.*)/)
    ProbeResult.new(path, duration ? duration[1] : nil, title ? title[1] : nil)
  end

  def self.segment(path_in, path_out)
    FileUtils.mkdir_p(path_out)
    `ffmpeg -i "#{path_in}" -c:v libx264 -b:v 1024k -c:a libmp3lame -b:a 128k -vprofile baseline -level 13 -flags -global_header -map 0 -f segment -segment_time 4 -segment_list "#{path_out}/stream.m3u8" -segment_format mpegts "#{path_out}/stream%05d.ts"`
  end
end

class Movies

  class Movie < Struct.new(:id, :path, :title, :duration)
  end

  def initialize(folder)
    @folder = folder
    @movies = nil
    initialize_poller!
    @callbacks = { :all => [] }
  end

  def all(&blk)
    if @movies
      blk.call @movies
    else
      @callbacks[:all] << blk
    end
  end

  private

  def initialize_poller!
    EM.add_periodic_timer(3) do
      paths = Dir.glob("#{@folder}/**/*").select { |f| f.match(/(avi|mkv|mpg|mpeg|wmv)$/) }.map { |f| Pathname.new(f) }
      @movies = paths.map do |path|
        probe = FFmpeg.probe(path)
        rel_path = File.join(path.dirname.basename, path.basename)
        id = Digest::MD5.hexdigest(rel_path)
        Movie.new(id, rel_path, probe.name, probe.duration)
      end
      while @callbacks[:all].any?
        @callbacks[:all].pop.call @movies
      end
    end
  end

end

class Transfers

  class Transfer < Struct.new(:id, :name, :status_name, :down, :up, :progress, :eta)
    def connection=(conn)
      @connection = conn
    end

    def collection=(coll)
      @collection = coll
    end

    def start!
      collection_send :start
    end

    def stop!
      collection_send :stop
    end

    private
    def collection_send(action)
      @connection.send(action, self.id) do
        @collection.invalidate!
      end
    end

  end

  def initialize(host = '127.0.0.1', port = 9091)
    @transfers = nil
    @transmission_client = Transmission::Client.new(host, port)
    @callbacks = { :all => [] }
    initialize_poller!
  end

  def all(&blk)
    if @transfers
      blk.call @transfers
    else
      @callbacks[:all] << blk
    end
  end

  def find(id, &blk)
    self.all do |transfers|
      transfers.find { |t| t.id == id }.each { |t| blk.call t }
    end
  end

  def invalidate!
    @transfers = nil
  end

  private
  def initialize_poller!
    EM.add_periodic_timer(1) do
      @transmission_client.torrents do |torrents|
        @transfers = torrents.map do |tor|
          t = Transfer.new(tor.id, tor.name, tor.status_name, tor.rate_download, tor.rate_upload, tor.percent_done, tor.eta_text)
          t.connection, t.collection = @transmission_client, self
          t
        end
        while @callbacks[:all].any?
          @callbacks[:all].pop.call @transfers
        end
      end
    end
  end
end
