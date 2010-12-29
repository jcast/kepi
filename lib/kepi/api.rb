class Kepi

  ##
  # Inherit the Api class to define a new service api. The child class
  # may then be used as a standard Rack middleware.

  class Api

    # Raised when an endpoint is called but not defined
    class EndpointUndefined < Kepi::Exception; end

    # Default content-type to return.
    DEFAULT_CONTENT_TYPE = "application/json"

    # HTTP error code to use when validation fails.
    HTTP_INVALID = 400

    # HTTP error code to use when endpoint is undefined.
    HTTP_UNDEFINED = 404


    class << self
      # The path suffix to look for to return the api documentation.
      # Defaults to %r{/api(\.\w+)?} which allows for passing the format
      # param as "/path/api.format"
      attr_accessor :api_doc_suffix

      # Global setting to not raise errors when unexpected params are given.
      # Defaults to false. May be overridden by each endpoint individually.
      attr_accessor :allow_undefined_params
    end

    self.api_doc_suffix         = %r{/api(\.[^?/]+)?}
    self.allow_undefined_params = false


    ##
    # Define a new endpoint for this Api class.
    # If block is given, passes it the newly created Endpoint instance.

    def self.endpoint http_method, path
      new_endpoint = Endpoint.new http_method, path

      new_endpoint.allow_undefined_params = self.allow_undefined_params

      self.endpoints[http_method] << new_endpoint

      yield new_endpoint if block_given?
    end



    ##
    # The hash of Endpoint objects defined for this api.

    def self.endpoints
      @endpoints ||= Hash.new{|h,k| h[k] = Array.new }
    end


    ##
    # Pass through calls for undefined endpoints.

    def self.passthrough!
      @passthrough = true
    end



    # If used as middleware, the app given from the Rack stack.
    attr_reader :app


    ##
    # Initialize with the provided Rack app object.
    # May be used as full application by omitting the app argument.
    #
    # Supported options are:
    # :passthrough:: Bool - Allow undefined endoints through as-is.

    def initialize app=nil, options={}
      options, app  = app, nil if options.empty? && Hash === app

      @app          = app
      @original_env = nil
      @passthrough  = if options.has_key? :passthrough
                        options[:passthrough]
                      else
                        self.class.instance_variable_get "@passthrough"
                      end
    end


    ##
    # Call the validation or api documentation stack.

    def call env
      @original_env = env

      req = Rack::Request.new env.dup

      endpoint = find_endpoint req.path_info
      raise EndpointUndefined, self.api unless endpoint

      if req.path_info =~ %r{#{self.class.api_doc_suffix}$}i
        when_api req, endpoint

      else
        ep_resp = endpoint.call(req) ||
                  [200, {'Content-Type' => DEFAULT_CONTENT_TYPE}, ""]

        resp    = when_valid(req, endpoint)
        resp || ep_resp
      end

    rescue EndpointUndefined => err
      when_undefined req, err

    rescue Endpoint::ParamValidationError => err
      when_invalid req, err
    end


    ##
    # Returns the full api documentation.

    def api
      endpoints = self.class.endpoints.sort{|x,y| x.path <=> y.path}
      endpoints.map{|e| e.api}
    end


    ##
    # Find the first endpoint that matches the given path.
    # Returns an array containing the matcher, endpoint, and keys
    # Keys are used to process params in the path.

    def find_endpoint http_method, path
      self.class.endpoints[http_method].each do |endpoint|
        return endpoint if endpoint.matches path
      end

      nil
    end


    ##
    # Defines what to do when the api lookup is requested.

    def when_api req, endpoint
      [200, {'Content-Type' => DEFAULT_CONTENT_TYPE}, endpoint.api.to_json]
    end


    ##
    # Defines globally what to do when not all endpoint conditions are met.
    # By default, returns a 400 error with a json body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_invalid req, error
      [HTTP_INVALID, {'Content-Type' => DEFAULT_CONTENT_TYPE}, error.to_json]
    end


    ##
    # Defines globally what to do when not all endpoint conditions are met.
    # By default, returns a 404 error with a json body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_undefined req, error
      [HTTP_UNDEFINED, {'Content-Type' => DEFAULT_CONTENT_TYPE}, error.to_json]
    end


    ##
    # Defines globally what to do when all endpoint conditions are met.
    # By default, forwards the Rack request to the endpoint's defined action,
    # then to the app if used as middleware.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_valid req, endpoint
      @app.call req.env if @app
    end
  end
end
