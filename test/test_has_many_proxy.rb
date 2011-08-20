require 'helper'
require 'runeo/has_many_proxy'
require 'runeo/node'

class TestHasManyProxy < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  class Person < Runeo::Node
  end

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
    flexmock(@http).should_receive(:post).never
    flexmock(@http).should_receive(:get).never
    Runeo::HasManyProxy.new(Runeo::Node.new("id" => 1234), via: { child: :in })
  end

  def test_invoking_each_should_issue_http_request
    flexmock(@http).should_receive(:post).once.and_return(MockHTTP::Response.new("200", '[{"data":{"date":"1997-07-11"},"self":"/db/data/node/12"},{"data":{"date":"1985-03-08"},"self":"/db/data/node/13"}]'))
    Runeo::HasManyProxy.new(Runeo::Node.new("id" => 1234), via: { child: :in }).each
  end

  def test_invoking_each_twice_should_issue_only_a_single_http_request
    flexmock(@http).should_receive(:post).once.and_return(MockHTTP::Response.new("200", '[{"data":{"date":"1997-07-11"},"self":"/db/data/node/12"},{"data":{"date":"1985-03-08"},"self":"/db/data/node/13"}]'))
    proxy = Runeo::HasManyProxy.new(Runeo::Node.new("id" => 1234), via: { child: :in })
    proxy.each
    proxy.each
  end

  def test_contents_should_be_nodes
    expected_query = '{"max_depth":1,"relationships":[{"direction":"in","type":"child"}]}'
    @http.on :post, "/db/data/node/1234/traverse/node with #{expected_query}", '[{"data":{"date":"1997-07-11"},"self":"/db/data/node/12"},{"data":{"date":"1985-03-08"},"self":"/db/data/node/13"}]'
    proxy = Runeo::HasManyProxy.new(Runeo::Node.new("id" => 1234), via: { child: :in })
    assert_equal 2, proxy.length
    assert_equal [12, 13], proxy.map(&:id)
    assert_equal [Runeo::Node, Runeo::Node], proxy.map(&:class)
  end
  
  def test_create_should_create_new_node_and_new_relationship
    expected_node_query = '{"name":"Jamis","_type":"TestHasManyProxy::Person"}'
    expected_relationship_query = '{"to":"/db/data/node/11","type":"child"}'

    @http.on :post, "/db/data/node with #{expected_node_query}", '{"self":"/db/data/node/12","data":{"name":"Jamis","_type":"TestHasManyProxy::Person"}}'
    @http.on :post, "/db/data/node/12/relationships with #{expected_relationship_query}", '{"start":"/db/data/node/12","data":{},"type":"child","self":"/db/data/relationship/1","end":"/db/data/node/11"}'

    proxy = Runeo::HasManyProxy.new(Runeo::Node.new("id" => 11), via: { child: :in }, class: "TestHasManyProxy::Person")
    node = proxy.create("name" => "Jamis")

    assert_equal 12, node.id
    assert_equal "Jamis", node.name
    assert_instance_of TestHasManyProxy::Person, node
  end

  def test_push_should_add_existing_node_with_new_relationship
    expected_relationship_query = '{"to":"/db/data/node/11","type":"child"}'

    @http.on :post, "/db/data/node/12/relationships with #{expected_relationship_query}", '{"start":"/db/data/node/12","data":{},"type":"child","self":"/db/data/relationship/1","end":"/db/data/node/11"}'

    node1 = Runeo::Node.new("id" => 11)
    node2 = Runeo::Node.new("id" => 12)

    proxy = Runeo::HasManyProxy.new(node1, via: { child: :in }, class: "TestHasManyProxy::Person")
    node3 = proxy.push(node2)

    assert_equal node2.object_id, node3.object_id
  end
end
