require 'helper'
require 'runeo/relationship'

class TestRelationship < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  def setup
    @http = MockHTTP.new
    Runeo::Base.transport = flexmock("transport", :start => @http)
    Runeo::Base.url = "http://localhost:7474"
  end

  def teardown
    Runeo::Base.reset
  end

  def test_find_on_should_issue_http_request_for_relationships_of_given_node
    @http.on :get, "/db/data/node/1234/relationships/all", '[{"start":"/db/data/node/1234","data":{},"type":"CHILD","end":"/db/data/node/1235","self":"/db/data/relationship/1"},{"start":"/db/data/node/1236","data":{},"type":"SPOUSE","end":"/db/data/node/1234","self":"db/data/relationship/2"}]'
    list = Runeo::Relationship.find_on(flexmock("node", :id => 1234))
    assert_equal list.length, 2
    assert_equal list[0].type, "CHILD"
    assert_equal list[1].type, "SPOUSE"
  end

  def test_create_should_issue_post_request_to_create_relationship_between_nodes
    @http.on :post, '/db/data/node/123/relationships with {"to":"/db/data/node/125","type":"SPOUSE"}',
      '{"start":"/db/data/node/123","data":{},"type":"SPOUSE","self":"/db/data/relationship/1","end":"/db/data/node/125"}'
    record = Runeo::Relationship.create 123, 125, "SPOUSE"
    assert_equal 1, record.id
    assert_equal 123, record.start_node_id
    assert_equal 125, record.end_node_id
    assert_equal "SPOUSE", record.type
  end
end
