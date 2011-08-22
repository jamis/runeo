require 'json'
require 'active_support/core_ext/string'

require 'runeo/base'
require 'runeo/has_many_proxy'
require 'runeo/relationship_proxy'

module Runeo
  class Node < Base
    Association = Struct.new :name, :type, :relationships

    class <<self
      def find(id)
        response = connection.get("/db/data/node/#{id.to_i}")
        instantiate JSON.parse(response.body)
      end

      def instantiate(hash)
        id = extract_id(hash["self"])
        data = hash["data"] || {}
        type = data["_type"] || "Runeo::Node"
        type.constantize.new data.merge("id" => id)
      end

      def create(attrs={})
        payload = attrs.merge(_type: self.name).to_json
        response = connection.post("/db/data/node", payload, "application/json")
        instantiate JSON.parse(response.body)
      end

      def has_many(association_name, options={})
        add_association(association_name, :has_many, options)

        class_eval <<-CODE, __FILE__, __LINE__+1
          def #{association_name}
            @_#{association_name} ||= Runeo::HasManyProxy.new(self, #{options.inspect})
          end

          def set_#{association_name}_target(list)
            @_#{association_name} = Array(list)
          end
        CODE
      end

      def has_one(association_name, options={})
        add_association(association_name, :has_one, options)

        class_eval <<-CODE, __FILE__, __LINE__+1
          def #{association_name}
            @_#{association_name} ||= Runeo::HasManyProxy.new(self, #{options.inspect}).to_a.first
          end

          def #{association_name}=(node)
            Runeo::HasManyProxy.new(self, #{options.inspect}).push(node)
            node
          end

          def set_#{association_name}_target(node)
            @_#{association_name} = node
          end
        CODE
      end

      def association_for(relationship_name, relationship_dir)
        relationship_name = relationship_name.to_sym
        relationship_dir = relationship_dir.to_sym

        associations.each do |name, association|
          association.relationships.each do |name, direction|
            if name == relationship_name && (direction == :all || direction == relationship_dir)
              return association
            end
          end
        end

        superclass.respond_to?(:association_for) ?
          superclass.association_for(relationship_name, relationship_dir) :
          nil
      end

      def associations
        @associations || {}
      end

      private

      def add_association(name, type, options)
        @associations ||= {}
        @associations[name] = Association.new(name, type, options[:via])
      end
    end

    def destroy
      response = self.class.connection.delete("/db/data/node/#{id}")
      return true if response.code == "204"
      raise "unexepcted `delete' response: #{response.code} (#{response.body})"
    end

    def relationships
      @relationships ||= Runeo::RelationshipProxy.new(self)
    end

    def query(options={})
      query = {}

      query[:max_depth] = options[:depth] if options[:depth]
      if options[:relationships]
        query[:relationships] = []
        options[:relationships].each do |type, direction|
          query[:relationships] << { direction: direction, type: type }
        end
      end

      # query the relationship graph
      response = self.class.connection.post("/db/data/node/#{id}/traverse/relationship", query.to_json, "application/json")
      relationships = JSON.parse(response.body)
      # node_map[node_id][type][dir] = [list of other node ids]
      node_map = Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = [] } } }

      # build the map of unique node ids in the relationship graph
      relationships.each do |relationship|
        start_id = Runeo::Base.extract_id(relationship["start"])
        end_id = Runeo::Base.extract_id(relationship["end"])
        node_map[start_id][relationship["type"]][:out] << end_id
        node_map[end_id][relationship["type"]][:in] << start_id
      end

      # query the nodes
      batch = node_map.keys.sort.map { |id| { method: "GET", to: "/node/#{id}" } }
      response = self.class.connection.post("/db/data/batch", batch.to_json, "application/json")
      responses = JSON.parse(response.body)

      nodes = responses.map { |data| Runeo::Node.instantiate(data["body"]) }
      nodes_by_id = nodes.inject({}) { |hash, node| hash[node.id] = (node.id == id ? self : node); hash }

      # connect the dots
      nodes_by_id.values.each do |node|
        node_map[node.id].each do |type, map|
          map.each do |direction, list|
            association = node.class.association_for(type, direction)
            raise "no matching association on #{node} for [#{type}, #{direction}]" unless association

            nodes = list.map { |id| nodes_by_id[id] }
            case association.type
              when :has_many then
                node.send "set_#{association.name}_target", nodes
              when :has_one then
                node.send "set_#{association.name}_target", nodes.first
              else
                raise NotImplementedError, "don't know how to hook up associations of type #{association.type.inspect}"
            end
          end
        end
      end

      self
    end
  end
end
