require 'pathname'
require 'fileutils'
require 'digest/md5'

# http://ruhe.tumblr.com/post/565540643/generate-json-from-ruby-struct
module HashableStruct
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    self.to_map.to_json(*a)
  end
end

module FFmpeg
  class ProbeResult < Struct.new(:path, :duration, :title)
    include HashableStruct
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

  def self.segment(path_in, path_out, base_name = 'stream')
    FileUtils.mkdir_p(path_out)
    `cd "#{path_out}" ; ffmpeg -v quiet -i "#{path_in}" -c:v libx264 -b:v 1024k -c:a libmp3lame -b:a 128k -vprofile baseline -level 13 -flags -global_header -map 0 -f segment -segment_time 4 -segment_list "#{base_name}.m3u8" -segment_format mpegts "#{base_name}%05d.ts"`
  end
end

class Streams

  class Stream < Struct.new(:id, :path, :source, :title, :status)
    include HashableStruct
    def initial?
      self.status == "initial"
    end
    def complete?
      self.status == "complete"
    end
  end

  def initialize(folder)
    @folder = folder
  end

  def all
    Dir.glob("#{@folder}/*.json").map do |path|
      meta = begin
               JSON.parse(IO.read(path))
             rescue Errno::ENOENT => ex
               {}
             end
      id = File.basename(path, '.json')
      Stream.new(id, path, meta["source"], meta["title"], meta["status"])
    end
  end

  def find(id)
    self.all.find { |s| s.id == id }
  end

  def find_by_path(path)
    find(make_id_from_path(path))
  end

  def create(source_path)
    id = make_id_from_path(source_path)
    probe = FFmpeg.probe(source_path)
    Stream.new(id, "#{@folder}/#{id}.json", source_path, probe.name, "initial")
  end

  def save!(stream, status = nil)
    File.open(stream.path, 'w') do |f|
      f.write(JSON.generate({"source" => stream.source, "title" => stream.title, "status" => status || stream.status}))
    end
  end

  private

  def make_id_from_path(path)
    unique = File.join(File.basename(File.dirname(path)), File.basename(path))
    Digest::MD5.hexdigest(unique)
  end
end

class Encoder
  def initialize(transfers, streams)
    @transfers = transfers
    @streams = streams
  end

  def queue_transfers
    @transfers.all.each do |t|
      if t.progress == 100
        t.movie_files.each do |m|
          unless @streams.find_by_path(m)
            puts "Creating new stream"
            s = @streams.create(m)
            @streams.save! s
          end
        end
      end
    end
  end

  def encode_streams
    @streams.all.each do |s|
      if s.initial?
        puts "Starting encoding of #{s.id}"
        @streams.save!(s, "encoding")
        FFmpeg.segment(s.source, File.join(File.dirname(s.path), s.id), 'stream')
        puts "Done encoding #{s.id}"
        @streams.save!(s, "complete")
      end
    end
  end
end

class Movies

  class Movie < Struct.new(:id, :path, :title, :duration)
    include HashableStruct
  end

  def initialize(folder)
    @folder = folder
    @movies = nil
    initialize_poller!
  end

  def all
    @movies
  end

  private

  def initialize_poller!
    Thread.new do
      while true
        begin
          paths = Dir.glob("#{@folder}/**/*").select { |f| f.match(/(avi|mkv|mpg|mpeg|wmv)$/) }.map { |f| Pathname.new(f) }
          @movies = paths.map do |path|
            probe = FFmpeg.probe(path)
            rel_path = File.join(path.dirname.basename, path.basename)
            id = Digest::MD5.hexdigest(rel_path)
            Movie.new(id, rel_path, probe.name, probe.duration)
          end
        rescue Exception => e
          p e
        end
        sleep 3
      end
    end
  end
end

class Transfers

  class Transfer < Struct.new(:id, :name, :download_dir, :status, :down, :up, :progress, :eta)
    include HashableStruct

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

    def movie_files
      folder = File.join(self.download_dir, self.name)
      Dir.glob("#{folder}/**/*").select { |f| f.match(/(avi|mkv|mpg|mpeg|wmv)$/) }.map { |f| Pathname.new(f) }
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
    @transmission_client = TransmissionClient::Client.new(host, port)
    initialize_poller!
  end

  def all
    @transfers || []
  end

  def find(id)
    @transfers.find { |t| t.id.to_i == id.to_i } if @transfers.any?
  end

  def invalidate!
    @transfers = nil
  end

  def add_torrent_by_file(url)
    @transmission_client.add_torrent_by_url(url)
  end

  private

  def initialize_poller!
    Thread.new do
      while true
        begin
          @transfers = @transmission_client.torrents.map do |tor|
            t = Transfer.new(tor.id, tor.name, tor.download_dir, tor.status_name, tor.rate_download, tor.rate_upload, tor.percent_done, tor.eta_text)
            t.connection, t.collection = @transmission_client, self
            t
          end
        rescue Exception => e
          puts e.class.to_s + ": " + e.message
          puts e.backtrace.join("\n")
        end
        sleep 1
      end
    end
  end
end
