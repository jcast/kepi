require 'test/test_helper'

class TestKepiEndpoint < Test::Unit::TestCase

  def setup
    @endpoint = Kepi::Endpoint.new :get, "resource/:id"
    @endpoint.description = "Get the resource with specified id"

    @endpoint.required_param(/^search_term|q$/, String)
    @endpoint.required_param :zip, /\d{5}(-\d{4})?/

    @endpoint.optional_param(/^limit|h$/,  Integer)
    @endpoint.optional_param(/^offset|o$/, Integer)

    @matcher_hash = @endpoint.required_params
  end


  def test_call
    req = mock "req"
    req.stubs(:params).returns()
    
  end


  def test_matches
    assert @endpoint.matches("resource/1234")
    assert !@endpoint.matches("resource/1234/foobar")
  end


  def test_path_params
    id_param = @endpoint.required_params.find{|par| par.name == 'id'}

    assert Kepi::Endpoint::Param === id_param
    assert_equal(nil, id_param.validator)
  end


  def test_path_param_override
    @endpoint.required_param :id, Integer, "Id of the resource"
    id_param = @endpoint.required_params.find{|par| par.name == 'id'}

    assert_equal Integer, id_param.validator
    assert_equal "Id of the resource", id_param.description
  end


  def test_optional_param
    @endpoint.optional_param :q, String, "Query to send"
    id_param = @endpoint.optional_params.find{|par| par.name == 'q'}

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_required_param
    @endpoint.required_param :q, String, "Query to send"
    id_param = @endpoint.required_params.find{|par| par.name == 'q'}

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_required
    @endpoint.add_param :q, true, String, "Query to send"
    id_param = @endpoint.required_params.find{|par| par.name == 'q'}

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_optional
    @endpoint.add_param :q, false, String, "Query to send"
    id_param = @endpoint.optional_params.find{|par| par.name == 'q'}

    assert_equal String, id_param.validator
    assert_equal "Query to send", id_param.description
  end


  def test_add_param_no_validator
    @endpoint.add_param :q, false, "Query to send"
    id_param = @endpoint.optional_params.find{|par| par.name == 'q'}

    assert_equal(nil, id_param.validator)
    assert_equal "Query to send", id_param.description
  end


  def test_parse_path
    pattern, keys = Kepi::Endpoint.parse_path "resource/:id/:foo"
    assert_equal %r{^resource/([^/?#]+)/([^/?#]+)$}, pattern
    assert_equal ['id', 'foo'], keys
  end


  def test_parse_path_captures
    pattern, keys = Kepi::Endpoint.parse_path %r{resource/([^/]+)/(.*)}
    assert_equal %r{resource/([^/]+)/(.*)}, pattern
    assert_equal [], keys
  end


  def test_parse_path_splat
    pattern, keys = Kepi::Endpoint.parse_path "resource/:id/*/*"
    assert_equal %r{^resource/([^/?#]+)/(.*?)/(.*?)$}, pattern
    assert_equal ['id', 'splat', 'splat'], keys
  end


  def test_process_path_params
    endpoint = Kepi::Endpoint.new :get, "resource/:id/:foo"
    params   = endpoint.process_path_params "resource/1234/bar"

    expected = {'id' => "1234", 'foo' => "bar"}

    assert_equal expected, params
  end


  def test_process_path_params_splat
    endpoint = Kepi::Endpoint.new :get, "resource/:id/*/*"
    params   = endpoint.process_path_params "resource/1234/foo/bar"

    expected = {'id' => '1234', 'splat' => ['foo', 'bar']}

    assert_equal expected, params
  end


  def test_process_path_params_captures
    endpoint = Kepi::Endpoint.new :get, %r{resource/([^/]+)/(.*)}
    params   = endpoint.process_path_params "resource/1234/foo/bar"

    expected = {'captures' => ['1234', 'foo/bar']}

    assert_equal expected, params
  end


  def test_validate
    params = {
      :q   => "pizza",
      :zip => 91026,
      :id  => 1234
    }

    assert @endpoint.validate(params)
  end


  def test_validate_optional
    params = {
      :q      => "pizza",
      :zip    => 91026,
      :id     => 1234,
      :limit  => 3,
      :offset => 4
    }

    assert @endpoint.validate(params)
  end


  def test_validate_undefined
    params = {
      :q      => "pizza",
      :zip    => 91026,
      :id     => 1234,
      :thing  => "oops"
    }

    assert_raises Kepi::ParamUndefined do
      assert @endpoint.validate(params)
    end
  end


  def test_validate_undefined_ok
    params = {
      :q      => "pizza",
      :zip    => 91026,
      :id     => 1234,
      :thing  => "oops"
    }

    @endpoint.allow_undefined_params = true

    assert @endpoint.validate(params)
  end


  def test_validate_no_id
    params = {
      :q   => "pizza",
      :zip => 91026
    }

    assert_raises Kepi::ParamMissing do
      assert @endpoint.validate(params)
    end
  end


  def test_match_value
    assert @endpoint.match_value("test", :test)
    assert !@endpoint.match_value("test", 123)

    assert @endpoint.match_value(Symbol, :test)
    assert !@endpoint.match_value(Symbol, "test")

    assert @endpoint.match_value('a'..'d', "d")
    assert !@endpoint.match_value('a'..'d', "z")

    assert @endpoint.match_value([1,3,5,7,9], 3)
    assert !@endpoint.match_value([1,3,5,7,9], 2)

    assert @endpoint.match_value(/\d+/, 123)
    assert !@endpoint.match_value(/\d+/, "test")

    assert @endpoint.match_value(nil, 123)
    assert !@endpoint.match_value(nil, "")
    assert !@endpoint.match_value(nil, [])
    assert !@endpoint.match_value(nil, {})
    assert !@endpoint.match_value(nil, nil)
  end


  def test_action_handler
    ran = false

    @endpoint.on_action do
      ran = true
    end

    @endpoint.action_handler.call
    assert ran
  end


  def test_error_handler
    ran = false

    @endpoint.on_error do
      ran = true
    end

    @endpoint.error_handler.call
    assert ran
  end


  def test_validation_error_handler
    ran = false

    @endpoint.on_validation_error do
      ran = true
    end

    @endpoint.validation_error_handler.call
    assert ran
  end


  def test_api_doc_handler
    ran = false

    @endpoint.on_api_doc do
      ran = true
    end

    @endpoint.api_doc_handler.call
    assert ran
  end
end
