require 'test/test_helper'

class TestKepiEndpoint < Test::Unit::TestCase

  def setup
    @endpoint = Kepi::Endpoint.new :get, "resource/:id"
    @endpoint.description = "Get the resource with specified id"
  end


  def test_path_params
    id_param = @endpoint.mandatory_params['id']

    assert Kepi::Endpoint::Param === id_param
    assert_equal(/.+/, id_param.validator)
  end


  def test_path_param_override
    @endpoint.mandatory_param :id, Integer, "Id of the resource"
    id_param = @endpoint.mandatory_params['id']

    assert_equal Integer, id_param.validator
    assert_equal "Id of the resource", id_param.description
  end


  def test_optional_param
    @endpoint.optional_param :q, String, "Query to send"
    id_param = @endpoint.optional_params['q']

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_mandatory_param
    @endpoint.mandatory_param :q, String, "Query to send"
    id_param = @endpoint.mandatory_params['q']

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_mandatory
    @endpoint.add_param :q, true, String, "Query to send"
    id_param = @endpoint.mandatory_params['q']

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_optional
    @endpoint.add_param :q, false, String, "Query to send"
    id_param = @endpoint.optional_params['q']

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_no_validator
    @endpoint.add_param :q, false, "Query to send"
    id_param = @endpoint.optional_params['q']

    assert_equal(/.+/, id_param.validator)
    assert_equal "Query to send", id_param.description
  end
end
