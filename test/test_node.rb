require 'helper'
require 'runeo/node'

class TestNode < MiniTest::Unit::TestCase
  include FlexMock::TestCase

  class Person < Runeo::Node
    has_many :parents, via: { child: :in }, class: "TestNode::Union"
    has_many :marriages, via: { husband: :in, wife: :in }, class: "TestNode::Union"
    has_one  :fingerprint, via: { id: :out }
  end

  class Union < Runeo::Node
    has_many :children, via: { child:   :out }, class: "TestNode::Person"
    has_one  :husband,  via: { husband: :out }
    has_one  :wife,     via: { wife:    :out }
  end

  def setup
    @http = MockHTTP.new
    Runeo::Base.transport = flexmock("transport", :start => @http)
    Runeo::Base.url = "http://localhost:7474"
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

  def test_query_should_construct_relationship_traversal_query_and_then_get_all_nodes_in_one_query
    traversal_query = {max_depth:4, relationships:[{direction:"in", type:"child"},{direction:"out", type:"husband"},{direction:"out", type:"wife"}]}.to_json
    traversal_response = [_r(1,2,1,"child"), _r(2,2,3,"husband"), _r(3,2,4,"wife"),
                          _r(4,5,3,"child"), _r(5,5,6,"husband"), _r(6,5,7,"wife")].to_json

    types = { 1 => "TestNode::Person", 2 => "TestNode::Union", 3 => "TestNode::Person",
              4 => "TestNode::Person", 5 => "TestNode::Union", 6 => "TestNode::Person", 7 => "TestNode::Person" }

    batch_query = (1..7).map { |id| { method: "GET", to: "/node/#{id}" } }.to_json
    batch_response = (1..7).map { |id| _b(id, "/node/#{id}", _n(id, name: (64+id).chr, _type: types[id])) }.to_json

    person = Person.new("id" => 1)
    @http.on :post, "/db/data/node/1/traverse/relationship with #{traversal_query}", traversal_response
    @http.on :post, "/db/data/batch with #{batch_query}", batch_response

    root = person.query depth: 4, relationships: { child: :in, husband: :out, wife: :out }

    assert_equal root.object_id, person.object_id, "root object should be same as self"
    assert_equal root.parents[0].name, "B"
    assert_equal root.parents[0].husband.name, "C"
    assert_equal root.parents[0].wife.name, "D"
    assert_equal root.parents[0].husband.parents[0].name, "E"
    assert_equal root.parents[0].husband.parents[0].husband.name, "F"
    assert_equal root.parents[0].husband.parents[0].wife.name, "G"
  end

  private

  def _r(self_id, start_id, end_id, type, data={})
    { start: "/db/data/node/#{start_id}",
      end:   "/db/data/node/#{end_id}",
      type:  type,
      self:  "/db/data/relationship/#{self_id}",
      data:  data }
  end

  def _b(id, from, body=nil)
    b = { id: id, from: from }
    b[:body] = body if body
    b
  end

  def _n(id, data={})
    { self: "/db/data/node/#{id}",
      data: data }
  end
end
