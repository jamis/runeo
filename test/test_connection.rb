require 'helper'
require 'runeo/connection'

class TestConnection < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  def setup
    @http = flexmock("http")
    @http.should_receive(:start => @http).once
    @connection = Runeo::Connection.new(@http, "localhost", 7474)
  end

  def test_get_should_send_HTTP_get_request
    @http.should_receive(:get).with("/path/to/resource", headers).and_return(response)
    assert_equal "200", @connection.get("/path/to/resource").code
  end

  def test_get_should_raise_exception_when_response_is_not_2xx
    @http.should_receive(:get).with("/path/to/resource", headers).and_return(response "not found", "404")
    begin
      @connection.get "/path/to/resource"
    rescue Runeo::Connection::Error => error
      assert_equal "404", error.response.code
      assert_equal "not found", error.response.body
    else
      flunk "expected error to be raised"
    end
  end

  def test_post_should_send_HTTP_post_request
    payload = "the body of the payload"
    @http.should_receive(:post).with("/path/to/resource", payload, headers('Content-Type' => 'text')).and_return(response)
    assert_equal "200", @connection.post("/path/to/resource", payload, 'text').code
  end

  def test_post_should_raise_exception_when_response_is_not_2xx
    payload = "the body of the payload"
    @http.should_receive(:post).with("/path/to/resource", payload, headers('Content-Type' => 'text')).and_return(response "not found", "404")
    begin
      @connection.post "/path/to/resource", payload, 'text'
    rescue Runeo::Connection::Error => error
      assert_equal "404", error.response.code
      assert_equal "not found", error.response.body
    else
      flunk "expected error to be raised"
    end
  end

  def test_put_should_send_HTTP_put_request
    payload = "the body of the payload"
    @http.should_receive(:put).with("/path/to/resource", payload, headers('Content-Type' => 'text')).and_return(response)
    assert_equal "200", @connection.put("/path/to/resource", payload, 'text').code
  end

  def test_put_should_raise_exception_when_response_is_not_2xx
    payload = "the body of the payload"
    @http.should_receive(:put).with("/path/to/resource", payload, headers('Content-Type' => 'text')).and_return(response "not found", "404")
    begin
      @connection.put "/path/to/resource", payload, 'text'
    rescue Runeo::Connection::Error => error
      assert_equal "404", error.response.code
      assert_equal "not found", error.response.body
    else
      flunk "expected error to be raised"
    end
  end

  def test_delete_should_send_HTTP_delete_request
    @http.should_receive(:delete).with("/path/to/resource", headers).and_return(response)
    assert_equal "200", @connection.delete("/path/to/resource").code
  end

  def test_delete_should_raise_exception_when_response_is_not_2xx
    @http.should_receive(:delete).with("/path/to/resource", headers).and_return(response "not found", "404")
    begin
      @connection.delete "/path/to/resource"
    rescue Runeo::Connection::Error => error
      assert_equal "404", error.response.code
      assert_equal "not found", error.response.body
    else
      flunk "expected error to be raised"
    end
  end

  private

  def headers(headers={})
    {'Accept' => 'application/json'}.merge(headers)
  end

  def response(body="success", code="200")
    flexmock("response", code: code.to_s, body: body.to_s)
  end
end
