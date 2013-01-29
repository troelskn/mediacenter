require 'sinatra/base'
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'boilerplate'
require 'models'
require 'transmission_client'

def stream_url(stream)
  "streams/#{stream.id}/stream.m3u8"
end

class App < Sinatra::Base

  configure do
    set :public_folder, Proc.new { File.join(root, "public") }
    set :streams_folder, Proc.new { File.join(root, "streams") }
  end

  error do
    "Error: #{request.env['sinatra.error'].to_s}"
  end

  helpers do

    def json(data, status_code = 200)
      status status_code
      content_type :json
      body data.to_json
    end

    def transfers
      Globals.transfers ||= Transfers.new
    end

    def streams
      Globals.streams ||= Streams.new(settings.streams_folder)
    end

    def transfer_to_hash(t)
      status = t.status
      if t.progress == 100
        encoding_complete = t.movie_files.map { |m| s = streams.find_by_path(m) ; s && s.complete? }.reduce(true) { |a,b| a && b }
        status = encoding_complete ? 'complete' : 'encoding'
      end
      t.to_map.merge({:status => status})
    end

    def stream_to_hash(s)
      s.to_map.merge({:href => "streams/#{s.id}/stream.m3u8" })
    end

  end

  get '/' do
    send_file File.expand_path('index.html', settings.public_folder)
  end

  post '/transfers' do
    result = transfers.add_torrent_by_file(params[:url])
    if params[:redirect]
      redirect "/"
    else
      json result
    end
  end

  get '/transfers' do
    json transfers.all.map { |t| transfer_to_hash t }
  end

  get '/transfers/:id' do |id|
    json transfer_to_hash(transfers.find(id))
  end

  put '/transfers/:id' do |id|
    t = transfers.find(id)
    method = params[:status] == 'stop' ? :stop! : :start!
    t.send(method)
    json({:status => "ok"})
  end

  get '/streams' do
    json streams.all.select { |s| s.complete? }.map { |s| stream_to_hash s }
  end

  get '/streams/:id/stream.m3u8' do |id|
    s = streams.find(id)
    file_name = File.join(File.dirname(s.path), s.id, "stream.m3u8")
    send_file file_name, :type => 'application/x-mpegURL', :disposition => 'inline'
  end

  get '/streams/:id/:segment.ts' do |id, segment|
    s = streams.find(id)
    file_name = File.join(File.dirname(s.path), s.id, "#{segment}.ts")
    puts "Serving #{file_name}"
    send_file file_name, :type => 'video/MP2T', :disposition => nil
  end
end
