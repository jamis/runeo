require 'minitest/unit'
require 'flexmock'

class MockHTTP
  Response = Struct.new(:code, :body)

  attr_reader :requests

  def initialize
    @map = Hash.new { |h,k| h[k] = {} }
    @requests = Hash.new(0)
  end

  def get(path, headers={})
    @requests[:get] += 1
    @map[:get][path]
  end

  def post(path, payload, headers={})
    @requests[:post] += 1
    @map[:post][path + " with " + payload]
  end

  def delete(path, headers={})
    @requests[:delete] += 1
    @map[:delete][path]
  end

  def on(method, key, body, code="200")
    @map[method][key] = Response.new(code.to_s, body.to_s)
  end
end
