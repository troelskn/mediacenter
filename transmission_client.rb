require 'net/http'
require 'json'

# https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
module TransmissionClient

  class Client
    def initialize(host = 'localhost', port = 9091, username = nil, password = nil)
      @connection = HttpConnection.new(host, port, username, password)
    end

    def torrents
      response = @connection.request('torrent-get', {'fields' => Torrent::ATTRIBUTES})
      response ? response['torrents'].map { |t| Torrent.new(t, @connection) } : []
    end

    def add_torrent_by_url(url)
      @connection.request('torrent-add', {'filename' => url})
    end

    def start(id)
      @connection.request('torrent-start', {'ids' => [*id].map(&:to_i)})
    end

    def stop(id)
      @connection.request('torrent-stop', {'ids' => [*id].map(&:to_i)})
    end

    def destroy!(id)
      @connection.request('torrent-remove', {'ids' => [*id].map(&:to_i), 'delete-local-data' => true})
    end

    def session
      response = @connection.request('session-get')
      Session.new(response, @connection)
    end

    def session_stat
      response = @connection.request('session-stats')
      SessionStat.new(response)
    end
  end

  class HttpConnection
    def initialize(host, port, username = nil, password = nil)
      @host = host
      @port = port
      @username = username
      @password = password
      @session_id = nil
      @http = Net::HTTP.new(@host, @port)
    end

    def request(method, attributes = {}, retrying = false)
      request = Net::HTTP::Post.new("/transmission/rpc")
      request.basic_auth(@username, @password) if @username
      request["x-transmission-session-id"] = @session_id if @session_id
      request["Content-Type"] = "application/json"
      json_body = build_json(method, attributes)
      request.body = json_body
      response = @http.request(request)
      case response.code.to_i
      when 401
        raise SecurityError, 'The client was not able to authenticate, is your username or password wrong?'
      when 409
        raise SecurityError, "Unable to get a valid session token" if retrying
        @session_id = response['x-transmission-session-id']
        request(method, attributes, true) # retry
      when 200
        struct = JSON.parse(response.body)
        if struct["result"] == 'success'
          struct['arguments']
        else
          struct
        end
      else
        raise "Unexpected HTTP status code #{response.code}"
      end
    end

    def build_json(method, attributes = {})
      if attributes.empty?
        {'method' => method}.to_json
      else
        {'method' => method, 'arguments' => attributes}.to_json
      end
    end
  end

  class Torrent
    ATTRIBUTES_READONLY = ['activityDate', 'addedDate', 'bandwidthPriority', 'comment', 'corruptEver', 'creator', 'dateCreated', 'desiredAvailable', 'doneDate', 'downloadDir', 'downloadedEver', 'downloadLimit', 'downloadLimited', 'error', 'errorString', 'eta', 'hashString', 'haveUnchecked', 'haveValid', 'honorsSessionLimits', 'id', 'isPrivate', 'leftUntilDone', 'manualAnnounceTime', 'maxConnectedPeers', 'name', 'peer-limit', 'peersConnected', 'peersGettingFromUs', 'peersKnown', 'peersSendingToUs', 'percentDone', 'pieces', 'pieceCount', 'pieceSize', 'rateDownload', 'rateUpload', 'recheckProgress', 'seedRatioLimit', 'seedRatioMode', 'sizeWhenDone', 'startDate', 'status', 'swarmSpeed', 'totalSize', 'torrentFile', 'uploadedEver', 'uploadLimit', 'uploadLimited', 'uploadRatio', 'webseedsSendingToUs']
    ATTRIBUTES = ATTRIBUTES_READONLY + ['bandwidthPriority', 'downloadLimit', 'downloadLimited', 'files-wanted', 'files-unwanted', 'honorsSessionLimits', 'ids', 'location', 'peer-limit', 'priority-high', 'priority-low', 'priority-normal', 'seedRatioLimit', 'seedRatioMode', 'uploadLimit', 'uploadLimited']
    attr_reader :attributes
    STATUS = {
      0 => :stopped,
      1 => :check_wait,
      2 => :check,
      3 => :download_wait,
      4 => :download,
      5 => :seed_wait,
      6 => :seed
    }

    def initialize(attributes, connection)
      @attributes = attributes
      @connection = connection
    end

    def to_json
      @attributes.to_json
    end

    def start
      @connection.request('torrent-start', {'ids' => @attributes['id']})
    end

    def stop
      @connection.request('torrent-stop', {'ids' => @attributes['id']})
    end

    def destroy!
      @connection.request('torrent-remove', {'ids' => @attributes['id'], 'delete-local-data' => true})
    end

    def status_name
      STATUS[self.status] || :unknown
    end

    def id
      @attributes['id']
    end

    def percent_done
      (method_missing(:percent_done) * 100).round
    end

    def eta_text
      secs = self.eta
      return "Done" if secs == -1
      [[60, :seconds], [60, :minutes], [24, :hours], [10000, :days]].map{ |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      }.compact.reverse.join(' ')
    end

    def method_missing(m, *args, &block)
      hyphen = m.to_s.gsub('_', '-')
      words = m.to_s.split('_')
      camel = words.inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
      if ATTRIBUTES.include? hyphen
        @attributes[hyphen]
      elsif ATTRIBUTES.include? camel
        @attributes[camel]
      elsif hyphen[-1..-1] == '='
        if ATTRIBUTES.include? hyphen[0..-2]
          name = hyphen[0..-2]
        elsif ATTRIBUTES.include? camel[0..-2]
          name = camel[0..-2]
        end
        if ATTRIBUTES_READONLY.include? name
          raise "Attribute is readonly."
        end
        @connection.request('torrent-set', {'ids' => [@attributes['id']], name => args.first})
      else
        raise "Invalid Attribute #{m} (#{hyphen}, #{camel})."
      end
    end
  end

  class Session
    ATTRIBUTES_READONLY = ["blocklist-size", "rpc-version", "rpc-version-minimum", "version"]
    ATTRIBUTES = ['alt-speed-down', 'alt-speed-enabled', 'alt-speed-time-begin', 'alt-speed-time-enabled', 'alt-speed-time-end', 'alt-speed-time-day', 'alt-speed-up', 'blocklist-enabled', 'download-dir', 'dht-enabled', 'encryption', 'incomplete-dir', 'incomplete-dir-enabled', 'peer-limit-global', 'peer-limit-per-torrent', 'pex-enabled', 'peer-port', 'peer-port-random-on-start', 'port-forwarding-enabled', 'seedRatioLimit', 'seedRatioLimited', 'speed-limit-down', 'speed-limit-down-enabled', 'speed-limit-up', 'speed-limit-up-enabled'] + ATTRIBUTES_READONLY
    attr_reader :attributes

    def initialize(attributes, connection)
      @attributes = attributes
      @connection = connection
    end

    def method_missing(m, *args, &block)
      hyphen = m.to_s.gsub('_', '-')
      words = m.to_s.split('_')
      camel = words.inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
      if ATTRIBUTES.include? hyphen
        @attributes[hyphen]
      elsif ATTRIBUTES.include? camel
        @attributes[camel]
      elsif hyphen[-1..-1] == '='
        if ATTRIBUTES.include? hyphen[0..-2]
          name = hyphen[0..-2]
        elsif ATTRIBUTES.include? camel[0..-2]
          name = camel[0..-2]
        end
        if ATTRIBUTES_READONLY.include? name
          raise "Attribute is readonly."
        end
        @connection.request('session-set', {name => args.first})
      else
        raise "Invalid Attribute."
      end
    end
  end

  class SessionStat
    ATTRIBUTES_READONLY = ['activeTorrentCount', 'downloadSpeed', 'pausedTorrentCount', 'torrentCount', 'uploadSpeed', 'cumulative-stats', 'current-stats']
    ATTRIBUTES = ATTRIBUTES_READONLY
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def method_missing(m, *args, &block)
      hyphen = m.to_s.gsub('_', '-')
      words = m.to_s.split('_')
      camel = words.inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
      if ATTRIBUTES.include? hyphen
        @attributes[hyphen]
      elsif ATTRIBUTES.include? camel
        @attributes[camel]
      elsif hyphen[-1..-1] == '='
        raise "Attribute is readonly."
      else
        raise "Invalid Attribute."
      end
    end
  end

end
