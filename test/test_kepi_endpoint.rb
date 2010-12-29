require 'test/test_helper'

class TestKepiEndpoint < Test::Unit::TestCase

  def setup
    @endpoint = Kepi::Endpoint.new :get, "resource/:id"
    @endpoint.description = "Get the resource with specified id"
  end

end
