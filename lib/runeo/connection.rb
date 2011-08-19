module Runeo
  class Connection
    class Error < RuntimeError
      attr_reader :response

      def initialize(message, response)
        @response = response
        super message
      end
    end

    attr_reader :host, :port

    def initialize(factory, host, port)
      @host, @port = host, port
      @http = factory.start(host, port)
    end

    def get(path)
      handle_response @http.get(path, {'Accept' => 'application/json'})
    end

    def post(path, payload, content_type)
      handle_response @http.post(path, payload, {'Accept' => 'application/json', 'Content-Type' => content_type})
    end

    def put(path, payload, content_type)
      handle_response @http.put(path, payload, {'Accept' => 'application/json', 'Content-Type' => content_type})
    end

    def delete(path)
      handle_response @http.delete(path, {'Accept' => 'application/json'})
    end

    private

    def handle_response(response)
      raise Error.new("HTTP response #{response.code}", response) if response.code[0] != ?2
      response
    end
  end
end
