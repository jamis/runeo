require 'helper'
require 'runeo/node'

class TestNode < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  class Person < Runeo::Node
    has_many :parents, via: { child: :in }, class: "TestNode::Union"
    has_one  :fingerprint, via: { id: :out }
  end

  class Union < Runeo::Node
    has_many :children, via: { child: :out }, class: "TestNode::Person"
  end

  def setup
    @http = MockHTTP.new
    Runeo::Base.transport = flexmock("transport", :start => @http)
  end

  def teardown
    Runeo::Base.reset
  end

  def test_find_should_return_new_node_object_with_given_nodes_properties
    @http.on :get, "/db/data/node/1", '{"self":"/db/data/node/1","data":{"name":"Jamis"}}'
    node = Runeo::Node.find(1)
    assert_equal 1, node.id
    assert_equal "Jamis", node.name
  end

  def test_find_should_instantiate_appropriate_node_type
    @http.on :get, "/db/data/node/1", '{"self":"/db/data/node/1","data":{"name":"Jamis"}}'
    @http.on :get, "/db/data/node/2", '{"self":"/db/data/node/2","data":{"name":"Jamis","_type":"TestNode::Person"}}'
    assert_instance_of Runeo::Node, Runeo::Node.find(1)
    assert_instance_of TestNode::Person, Runeo::Node.find(2)
  end

  def test_create_should_insert_new_node_and_return_corresponding_object
    @http.on :post, "/db/data/node with {\"name\":\"Jamis\",\"_type\":\"Runeo::Node\"}", '{"self":"http://localhost:7474/db/data/node/15", "data":{"name":"Jamis","_type":"Runeo::Node"}}', "201"
    node = Runeo::Node.create name: "Jamis"
    assert_equal 15, node.id
    assert_equal "Jamis", node.name
    assert_equal "Runeo::Node", node._type
  end

  def test_destroy_should_destroy_the_current_node_object
    @http.on :delete, "/db/data/node/15", "", "204"
    node = Runeo::Node.new("id" => 15, "name" => "Jamis")
    assert node.destroy
  end

  def test_relationships_should_return_a_proxy
    node = Runeo::Node.new("id" => 15, "name" => "Jamis")
    proxy = node.relationships
    assert_instance_of Runeo::RelationshipProxy, proxy
  end

  def test_has_many_should_create_reader_method
    assert Person.new.respond_to?(:parents), "expected Person to respond to :parents"
    assert Union.new.respond_to?(:children), "expected Union to respond to :children"
  end

  def test_has_many_should_create_helper_that_returns_a_proxy
    parents = Person.new("id" => 1).parents
    assert_instance_of Runeo::HasManyProxy, parents
  end

  def test_has_one_should_create_helper_that_performs_traversal_and_returns_first_match
    expected_query = '{"max_depth":1,"relationships":[{"direction":"out","type":"id"}]}'
    @http.on :post, "/db/data/node/1234/traverse/node with #{expected_query}", '[{"data":{"pattern":"whorl"},"self":"/db/data/node/12"},{"data":{"pattern":"arch"},"self":"/db/data/node/13"}]'
    fingerprint = Person.new("id" => 1234).fingerprint
    assert_equal "whorl", fingerprint.pattern
  end

  def test_has_one_should_create_writer_that_creates_relationship
    expected_relationship_query = '{"to":"/db/data/node/2345","type":"id"}'

    @http.on :post, "/db/data/node/1234/relationships with #{expected_relationship_query}", '{"start":"/db/data/node/1234","data":{},"type":"id","self":"/db/data/relationship/1","end":"/db/data/node/2345"}'

    Person.new("id" => 1234).fingerprint = Person.new("id" => 2345)
    assert_equal @http.requests[:post], 1
  end
end
