require 'thread'
require 'socket'
require 'websocket'

module Server

class RemoteDebugger
  WAIT_EXCEPTIONS  = [Errno::EAGAIN, Errno::EWOULDBLOCK]
  WAIT_EXCEPTIONS << IO::WaitReadable if defined?(IO::WaitReadable)

  NETWORK = {
  }

  PAGE = {
  }

  attr_accessor :send_count
  attr_accessor :network
  attr_accessor :message_resp

  def initialize(websocket_url)
    @network = []
    @message_resp = []
    @send_count = 0
    @handshaked = false
    @hs = WebSocket::Handshake::Client.new(:url => websocket_url)
    @socket = TCPSocket.new(@hs.host, @hs.port || 80)
    @frame ||= WebSocket::Frame::Incoming::Server.new(:version => @hs.version)
    @mutex = Mutex.new

    @socket.write(@hs.to_s)
    @socket.flush

    loop {
      data = @socket.getc
      next if data.nil?
      @hs << data

      if @hs.finished?
        raise @hs.error.to_s unless @hs.valid?
        @handshaked = true
        break
      end
    }
    start_listener
  end

  def start_listener
    raise "no handshake!" unless @handshaked
    Thread.new do
      while !@socket.closed? do
        data = @socket.recvfrom(2000).first
        @frame << data
        while frame = @frame.next do
          if frame.type == :close
            @socket.close
          else
            if frame.type === :ping
              send(frame.data, :pong)
              next
            end
            json_data = JSON.parse(frame.data) rescue {}
            if json_data.key?('method') && json_data['method'] =~ /Network/
              if json_data['method'] == "Network.requestWillBeSent"
                add_to_network_request(json_data)
              elsif json_data['method'] == "Network.responseReceived"
                add_to_network_response(json_data)
              end
              @network << json_data
              next
            end

            if json_data.key?('method') && json_data['method'] =~ /Page/
              add_to_page_notification(json_data)
              next
            end

            # messages << frame.to_s
            @message_resp << frame.data
          end
        end
      end
    end
  end

  def add_to_page_notification(json)
    @mutex.synchronize {
      PAGE['notifications'] ||= []
      PAGE['notifications'] << json
    }
  end

  def add_to_network_request(json)
    @mutex.synchronize {
      params = json['params']
      request = json['params']['request']
      NETWORK['request_id'] ||= {}
      NETWORK['request_id'][ params['requestId'] ] ||= []
      NETWORK['request_id'][ params['requestId'] ] << {
        :url          => request['url'],
        :method       => request['method'],
        :headers      => request['headers'],
        :post_data    => request['postData'].to_s,
        :type         => params['type'],
        :document_url => params['documentURL'],
        :response     => {}
      }
    }
  end

  def add_to_network_response(json)
    @mutex.synchronize {
      params = json['params']
      response = json['params']['response']
      if NETWORK['request_id'] && NETWORK['request_id'][ params['requestId'] ]
        NETWORK['request_id'][ params['requestId'] ].last.merge!(:response => params)
      end
    }
  end

  def network_data
    @mutex.synchronize {
      NETWORK
    }
  end

  def page_notifications
    @mutex.synchronize {
      PAGE
    }
  end

  def clear_network
    @mutex.synchronize {
      @network = []
      NETWORK.clear
    }
  end


  def send(json_str)
    data = WebSocket::Frame::Outgoing::Client.new(
      :version => @hs.version,
      :data => json_str,
      :type => :text
    ).to_s
    @socket.write data
    @socket.flush
    @send_count += 1
    result = receive()
  end

  def receive
    raise "no handshake!" unless @handshaked
    sleep 2
    [@message_resp.last].compact
  end

  def page_navigate(url)
    enable_page_notifications
    network_disable
    network_enable
    clear_network
    data = { :id => @send_count,
             :method => "Page.navigate",
             :params => {
               :url => url
             }
    }.to_json
    result = send(data)
  end

  def runtime_evaluate(js)
    data = {
      :id => @send_count,
      :method => "Runtime.evaluate",
      :params => {
        :expression => js.gsub(/"/, "\"")
      },
      :returnByValue => false
    }.to_json
    # puts "* JSON: #{ data.to_s }"
    result = send(data)
    # puts "\n\n RESULT: \n", result, "\n\n"
    result
  end

  def enable_page_notifications
    data = {
      :id     => @send_count,
      :method => "Page.enable"
    }.to_json
    result = send(data)
  end

  def network_enable
    data = {
      :id     => @send_count,
      :method => "Network.enable"
    }.to_json
    result = send(data)
    result
  end

  def network_disable
    @network = []
    data = {
      :id     => @send_count,
      :method => "Network.disable"
    }.to_json
    result = send(data)
    result
    @network = []
  end

  def network_traffic
    require 'pp'
    $stdout.puts "** ALL NETWORK: "
    $stdout.puts PP.pp(@network, ''), "\n\n"

    network_data
  end

  def page_get_cookies
    data = {
      :id     => @send_count,
      :method => "Page.getCookies"
    }.to_json
    result = send(data)
    result
  end

  def page_delete_cookie(name, url)
    data = {
      :id     => @send_count,
      :method => "Page.deleteCookie",
      :params => {
        :cookieName => name,
        :url        => url
      }
    }.to_json
    result = send(data)
    result
  end

  def page_reload
    data = {
      :id => @send_count,
      :method => "Page.reload",
      :params => {
        :ignoreCache => true
      }
    }.to_json
    result = send(data)
  end

  def set_extra_http_headers(headers)
    data = {
      :id     => @send_count,
      :method => "Network.setExtraHTTPHeaders",
      :params => {
        :headers => headers
      }
    }.to_json
    result = send(data)
  end

  def screenshot
    data = {
      :id     => @send_count,
      :method => "Page.snapshotRect",
      :params => {
        :x => 10,
        :y => 10,
        :width => 200,
        :height => 200,
        :coordinateSystem => 'Page'
      }
    }.to_json
    result = send(data)
  end
end

end
