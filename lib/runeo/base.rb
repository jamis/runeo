require 'net/http'
require 'uri'
require 'runeo/connection'
require 'runeo/relationship_proxy'

module Runeo
  class Base
    @@transport  = Net::HTTP
    @@url        = nil
    @@connection = nil

    class <<self
      def transport
        @@transport
      end

      def transport=(transport)
        @@transport = transport
      end

      def url
        @@url
      end

      def url=(uri)
        @@url = URI.parse(uri)
      end

      def connection
        @@connection ||= Connection.new(transport, url.host, url.port)
      end

      def reset
        @@connection = nil
      end

      def extract_id(url)
        url[/\/(\d+)$/, 1].to_i
      end
    end

    attr_reader :attributes

    def initialize(properties={})
      @attributes = properties.dup
    end

    def respond_to?(name)
      super || @attributes.key?(name.to_s)
    end

    def method_missing(name, *args, &block)
      name_str = name.to_s

      if @attributes.key?(name_str)
        @attributes[name_str]
      elsif name_str =~ /^(.*)=$/ && args.length == 1
        @attributes[$1] = args.first
      else
        super
      end
    end
  end
end
