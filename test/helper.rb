require 'minitest/unit'
require 'flexmock'

class MockHTTP
  Response = Struct.new(:code, :body)

  def initialize
    @map = Hash.new { |h,k| h[k] = {} }
  end

  def get(path, headers={})
    @map[:get][path]
  end

  def post(path, payload, headers={})
    @map[:post][path + " with " + payload]
  end

  def delete(path, headers={})
    @map[:delete][path]
  end

  def on(method, key, body, code="200")
    @map[method][key] = Response.new(code.to_s, body.to_s)
  end
end
