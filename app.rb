require 'sinatra/base'
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'models'
require 'transmission_client'

class App < Sinatra::Base

  configure do
    set :public_folder, Proc.new { File.join(root, "public") }
    set :streams_folder, Proc.new { File.join(root, "streams") }
    set :transfers, Transfers.new
    set :streams, Streams.new(settings.streams_folder)
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
      settings.transfers
    end

    def streams
      settings.streams
    end

    def transfer_to_hash(t)
      status = t.status
      progress_percent = t.progress
      if progress_percent > 0
        # TODO: This only makes sense once download has completed ..
        encoding_complete, duration, progress = true, 0, 0
        t.movie_files.each do |m|
          s = streams.find_by_path(m)
          if s
            encoding_complete = encoding_complete && s.complete?
            duration += s.duration if s.duration
            progress += s.progress if s.progress
          end
        end
        progress_percent = 100 - (((duration - progress) / duration.to_f) * 100).round if duration > 0
        status = encoding_complete ? 'complete' : 'encoding'
      end
      t.to_map.merge({:status => status, :progress => progress_percent})
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

  delete '/transfers/:id' do |id|
    t = transfers.find(id)
    transfers.delete t
  end

  get '/streams' do
    json streams.all.select { |s| s.complete? }.map { |s| stream_to_hash s }
  end

  get '/streams/:id/stream.m3u8' do |id|
    s = streams.find(id)
    file_name = File.join(File.dirname(s.path), s.id, "stream.m3u8")
    send_file file_name, :type => 'application/x-mpegURL', :disposition => 'inline'
  end

  delete '/streams/:id/stream.m3u8' do |id|
    s = streams.find(id)
    streams.delete s
  end

  get '/streams/:id/:segment.ts' do |id, segment|
    s = streams.find(id)
    file_name = File.join(File.dirname(s.path), s.id, "#{segment}.ts")
    puts "Serving #{file_name}"
    send_file file_name, :type => 'video/MP2T', :disposition => nil
  end
end
