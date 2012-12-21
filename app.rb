require 'sinatra/base'
require 'sinatra/async'
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'boilerplate'
require 'models'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'transmission-client', 'lib'))
require 'transmission-client'

class App < Sinatra::Base
  register Sinatra::Async

  configure do
    set :public_folder, Proc.new { File.join(root, "public") }
    # set :download_folder, Proc.new { "/Users/troelskn/Documents/Torrents" }
    set :media_folder, Proc.new { "/Users/troelskn/Documents/Movies" }
  end

  error do
    "Error: #{request.env['sinatra.error'].to_s}"
  end

  helpers do

    def json(data)
      status 200
      content_type :json
      body data.to_json
    end

    def transfers
      Globals.transfers ||= Transfers.new
    end

    def movies
      Globals.movies ||= Movies.new(settings.media_folder)
    end

  end

  get '/' do
    send_file File.expand_path('index.html', settings.public_folder)
  end

  aget '/transfers' do
    transfers.all do |t|
      json t
    end
  end

  aget '/transfers/:id' do |id|
    transfers.find(id) do |t|
      json t
    end
  end

  aput '/transfers/:id' do |id|
    transfers.find(id) do |t|
      if params[:status] == 'stop'
        t.stop!
      else
        t.start!
      end
      # todo
      transfers.find(id) do |t|
        json t
      end
    end
  end

  aget '/movies' do
    movies.all do |m|
      json m
    end
  end

  run!
end
