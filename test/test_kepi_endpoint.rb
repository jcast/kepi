require 'test/test_helper'

class TestKepiEndpoint < Test::Unit::TestCase

  def setup
    @endpoint = Kepi::Endpoint.new :get, "resource/:id"
  end

end
