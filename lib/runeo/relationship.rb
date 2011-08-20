require 'json'

require 'runeo/base'

module Runeo
  class Relationship < Base
    class <<self
      def find_on(node, direction=:all)
        response = connection.get("/db/data/node/#{node.id}/relationships/#{direction}")
        JSON.parse(response.body).map do |hash|
          id = extract_id(hash["self"])
          start_node_id = extract_id(hash["start"])
          end_node_id = extract_id(hash["end"])
          new hash["data"].merge("id" => id, "type" => hash["type"], "start_node_id" => start_node_id, "end_node_id" => end_node_id)
        end
      end

      def create(from, to, type)
        payload = { to: "/db/data/node/#{to}", type: type }.to_json
        response = connection.post("/db/data/node/#{from}/relationships", payload, "application/json")
        hash = JSON.parse(response.body)
        id = extract_id(hash["self"])
        start_node_id = extract_id(hash["start"])
        end_node_id = extract_id(hash["end"])
        new hash["data"].merge("id" => id, "type" => hash["type"], "start_node_id" => start_node_id, "end_node_id" => end_node_id)
      end
    end
  end
end
