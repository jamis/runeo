require 'helper'
require 'runeo/node'

class TestNode < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  class Person < Runeo::Node
    has_many :parents, via: { child: :in }, class: "TestNode::Union"
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
    @http.on :get, "/db/data/node/1", '{"data":{"name":"Jamis"}}'
    node = Runeo::Node.find(1)
    assert_equal 1, node.id
    assert_equal "Jamis", node.name
  end

  def test_create_should_insert_new_node_and_return_corresponding_object
    @http.on :post, "/db/data/node with {\"name\":\"Jamis\"}", '{"self":"http://localhost:7474/db/data/node/15", "data":{"name":"Jamis"}}', "201"
    node = Runeo::Node.create name: "Jamis"
    assert_equal 15, node.id
    assert_equal "Jamis", node.name
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

  def test_has_many_should_emit_query_to_return_all_immediate_neighbors_via_the_given_relationship
    expected_query = '{"max_depth":1,"relationships":[{"direction":"in","type":"child"}]}'
    @http.on :post, "/db/data/node/1/traverse/node with #{expected_query}", '[{"data":{"date":"1997-07-11"},"self":"/db/data/node/12"},{"data":{"date":"1985-03-08"},"self":"/db/data/node/13"}]'
    parents = Person.new("id" => 1).parents
    assert_equal 2, parents.length
    assert parents.all? { |p| p.instance_of?(Union) }
    assert_equal %w(1997-07-11 1985-03-08), parents.map(&:date)
    assert_equal [12, 13], parents.map(&:id)
  end
end
