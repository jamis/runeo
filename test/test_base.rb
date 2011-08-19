require 'helper'
require 'runeo/base'

class TestBase < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  def setup
    @http = flexmock("http")
    @http.should_receive(:start => @http)
    Runeo::Base.transport = @http
  end

  def teardown
    Runeo::Base.reset
  end

  def test_setting_url_should_initialize_connection
    Runeo::Base.url = "http://localhost:7474"
    assert_equal "localhost", Runeo::Base.connection.host
    assert_equal 7474, Runeo::Base.connection.port
  end

  def test_subclasses_should_inherit_connection
    Runeo::Base.url = "http://localhost:7474"
    subclass = Class.new(Runeo::Base)
    Runeo::Base.connection
    assert_equal Runeo::Base.connection.object_id, subclass.connection.object_id
  end

  def test_extract_id_should_pull_id_from_url
    assert_equal 1234, Runeo::Base.extract_id("http://localhost:7474/db/data/node/1234")
  end
end
