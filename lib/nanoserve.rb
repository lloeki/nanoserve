# frozen_string_literal: true

require 'socket'
require 'logger'
require 'time'

module NanoServe
  class TCPResponder
    def initialize(host, port, &block)
      @host  = host
      @port  = port
      @block = block
      @thr   = nil
      @srv   = nil
    end

    def start(y)
      @srv = TCPServer.new(@port)

      @thr = Thread.new do
        Thread.abort_on_exception = true
        conn = @srv.accept
        port, host = conn.peeraddr[1, 2]
        client = "#{host}:#{port}"
        logger.debug "#{client}: connected"

        begin
          @block.call(conn, y)
        rescue EOFError
          logger.debug "#{client}: disconnected"
        else
          logger.debug "#{client}: closed"
        ensure
          conn.close
        end
      end

      return unless block_given?

      yield

      @thr.join

      y
    end

    def stop
      @srv.close
      @thr.kill
    end

    def logger
      @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger::INFO }
    end
  end

  class HTTPResponder < TCPResponder
    def initialize(host, port)
      super(host, port) do |conn, y|
        req = Request.new
        buf = +''
        loop do
          line = conn.readline
          break if line.chomp == ''
          req << line
          buf << line
        end
        logger.debug "request:\n" + buf.gsub(/^/, '    ')

        res = Response.new
        logger.debug 'calling'
        yield(res, req, y)
        logger.debug "response:\n" + res.to_s.gsub(/^/, '    ')
        conn.write(res.to_s)
      end
    end

    class RequestError < StandardError; end

    class Request
      def initialize
        @method       = nil
        @uri          = nil
        @http_version = nil
        @sep          = nil
        @headers      = {}
      end

      def params
        Hash[*@uri.query.split('&').map { |kv| kv.split('=') }.flatten]
      end

      def <<(line)
        if @method.nil?
          parse_request(line.chomp)
        elsif @sep.nil?
          parse_header(line.chomp)
        else
          @body << line
        end
      end

      REQ_RE = %r{(?<method>[A-Z]+)\s+(?<path>\S+)\s+(?<version>HTTP/\d+.\d+)$}

      def parse_request(str)
        unless (m = str.match(REQ_RE))
          raise RequestError, "cannot parse request: '#{str}'"
        end

        @method       = parse_method(m[:method])
        @uri          = parse_path(m[:path])
        @http_version = parse_version(m[:version])
      end

      def parse_method(str)
        str
      end

      def parse_path(str)
        URI(str)
      end

      def parse_version(str)
        str
      end

      def parse_header(str)
        (@sep = '' && return) if str == ''

        unless (m = str.match(/(?<header>[A-Za-z][-A-Za-z]*):\s+(?<value>.+)$/))
          raise RequestError, "cannot parse header: '#{str}'"
        end

        @headers[m[:header]] = m[:value]
      end
    end

    class Response
      def headers
        {
          'Date'             => date,
          'Content-Type'     => content_type,
          'Content-Length'   => content_length,
          'Last-Modified'    => last_modified,
          'Server'           => server,
          'ETag'             => etag,
          'Connection'       => connection,
        }
      end

      def body
        @body ||= ''
      end

      def body=(value)
        @body = value.tap { @content_length = body.bytes.count.to_s }
      end

      def to_s
        (status_line + header_block + body_block).encode('ASCII-8BIT')
      end

      private

      def status_code
        200
      end

      def status_string
        'OK'
      end

      def status_line
        "HTTP/1.1 #{status_code} #{status_string}\r\n"
      end

      def header_block
        headers.map { |k, v| [k, v].join(': ') }.join("\r\n") + "\r\n\r\n"
      end

      def body_block
        body
      end

      def content_length
        @content_length ||= body.bytes.count.to_s
      end

      def content_type
        @content_type ||= 'text/html; charset=UTF-8'
      end

      def date
        @date ||= Time.now.httpdate
      end

      def last_modified
        @last_modified ||= date
      end

      def etag
        @etag ||= SecureRandom.uuid
      end

      def server
        'NanoServe'
      end

      def connection
        'close'
      end
    end
  end
end
