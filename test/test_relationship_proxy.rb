require 'helper'
require 'runeo/relationship_proxy'

class TestRelationshipProxy < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  def setup
    @http = MockHTTP.new
    Runeo::Base.transport = flexmock("transport", :start => @http)
    Runeo::Base.url = "http://localhost:7474"
  end

  def teardown
    super
    Runeo::Base.reset
  end

  def test_should_not_issue_http_requests_on_construction
    flexmock(@http).should_receive(:get).never
    Runeo::RelationshipProxy.new(flexmock("node"))
  end

  def test_invoking_length_should_issue_http_request
    @http.on :get, "/db/data/node/1234/relationships/all", '[{"start":"/db/data/node/1234","data":{},"type":"CHILD","end":"/db/data/node/1235","self":"/db/data/relationship/1"},{"start":"/db/data/node/1236","data":{},"type":"SPOUSE","end":"/db/data/node/1234","self":"db/data/relationship/2"}]'
    assert_equal 2, Runeo::RelationshipProxy.new(flexmock("node", :id => 1234)).length
  end

  def test_create_should_build_outgoing_relationship_by_default
    @http.on :post, '/db/data/node/123/relationships with {"to":"/db/data/node/125","type":"SPOUSE"}',
      '{"start":"/db/data/node/123","data":{},"type":"SPOUSE","self":"/db/data/relationship/1","end":"/db/data/node/125"}'
    proxy = Runeo::RelationshipProxy.new(flexmock("node", :id => 123))
    relationship = proxy.create(flexmock("node", :id => 125), "SPOUSE")
    assert_equal 1, relationship.id
    assert_equal 123, relationship.start_node_id
    assert_equal 125, relationship.end_node_id
    assert_equal "SPOUSE", relationship.type
  end
end
