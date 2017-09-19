# frozen_string_literal: true

require 'minitest/autorun'
require 'nanoserve'

require 'securerandom'
require 'uri'
require 'net/http'
require 'pry'
require 'pathname'

class TestNanoServe < MiniTest::Test
  def test_tcp_responder
    uuid = SecureRandom.uuid.encode('UTF-8')
    uri = URI('tcp://localhost:2000')

    r = NanoServe::TCPResponder.new(uri.host, uri.port) do |conn, buf|
      buf << conn.readpartial(1024)
    end

    buf = r.start(+'') do
      s = TCPSocket.new(uri.host, uri.port)
      s.write(uuid)
      s.close
    end

    r.stop

    assert_equal(uuid, buf)
  end

  def test_http_responder_get
    uuid = SecureRandom.uuid.encode('UTF-8')
    uri = URI('http://localhost:2000')

    r = NanoServe::HTTPResponder.new(uri.host, uri.port) do |res, req, y|
      y << req

      res.body = <<-EOS.gsub(/^ {8}/, '')
        <html>
        <head>
          <title>An Example Page</title>
        </head>
        <body>
          Hello World, this is a very simple HTML document.
        </body>
        </html>
      EOS
    end

    req = r.start([]) do
      Net::HTTP.get(uri + "test?uuid=#{uuid}")
    end

    r.stop

    assert_equal(uuid, req.first.params['uuid'])
  end

  def test_http_responder_post
    uuid = SecureRandom.uuid.encode('UTF-8')
    uri = URI('http://localhost:2000')

    r = NanoServe::HTTPResponder.new(uri.host, uri.port) do |res, req, y|
      y << req

      res.body = <<-EOS.gsub(/^ {8}/, '')
        <html>
        <head>
          <title>An Example Page</title>
        </head>
        <body>
          Hello World, this is a very simple HTML document.
        </body>
        </html>
      EOS
    end

    req = r.start([]) do
      Net::HTTP.post_form(
        uri + "test?uuid=#{uuid}&p=query",
        'p' => 'form',
        'f' => 'foo',
      )
    end

    r.stop

    assert_equal(uuid, req.first.params['uuid'])
    assert_equal(uuid, req.first.query['uuid'])
    assert_nil(req.first.form['uuid'])

    assert_equal('foo', req.first.params['f'])
    assert_nil(req.first.query['f'])
    assert_equal('foo', req.first.form['f'])

    assert_equal('form',  req.first.params['p'])
    assert_equal('query', req.first.query['p'])
    assert_equal('form',  req.first.form['p'])
  end
end
