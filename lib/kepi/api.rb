class Kepi

  ##
  # Inherit the Api class to define a new service api. The child class
  # may then be used as a standard Rack middleware.

  class Api

    # Raised when an endpoint is called but not defined
    class EndpointUndefined < Kepi::Exception; end


    # HTTP error code to use when validation fails.
    INVALID_HTTP_CODE = 400

    # HTTP error code to use when endpoint is undefined.
    UNDEFINED_HTTP_CODE = 404


    ##
    # Define a new endpoint for this Api class.
    # If block is given, passes it the newly created Endpoint instance.

    def self.endpoint http_method, path
      http_method   = http_method.to_s.upcase
      matcher, keys = matcher_for path

      new_endpoint = Endpoint.new

      self.endpoints[http_method][matcher] = [new_endpoint, keys]

      yield new_endpoint if block_given?
    end


    ##
    # Converts an endpoint path to its regex matcher.
    # (Thanks Sinatra!)

    def self.matcher_for path
      return path if Regexp === path

      special_chars = %w{. + ( )}

      pattern =
        path.to_str.gsub(/((:\w+)|[\*#{special_chars.join}])/) do |match|
          case match
          when "*"
            keys << 'splat'
            "(.*?)"
          when *special_chars
            Regexp.escape(match)
          else
            keys << $2[1..-1]
            "([^/?#]+)"
          end
        end

      [/^#{pattern}$/, keys]
    end


    ##
    # The hash of Endpoint objects defined for this api.

    def self.endpoints
      @endpoints ||= Hash.new{|h,k| h[k] = Hash.new }
    end


    ##
    # Pass through calls for undefined endpoints.

    def self.passthrough!
      @passthrough = true
    end


    ##
    # Initialize with the provided Rack app object.
    # Supported options are:
    # :passthrough:: Bool - Allow undefined endoints through as-is.

    def initialize app, options={}
      @app          = app
      @passthrough  = if options.has_key? :passthrough
                        options[:passthrough]
                      else
                        self.class.instance_variable_get "@passthrough"
                      end
    end


    ##
    # Call the validation stack.

    def call env
      req = Rack::Request.new env

      validate req.path_info, req.params
      when_valid @app, env

    rescue EndpointUndefined => err
      when_undefined @app, env, err

    rescue Kepi::Exception => err
      when_invalid @app, env, err
    end


    ##
    # Find the first endpoint that matches the given path.
    # Returns an array containing the matcher, endpoint, and keys
    # Keys are used to process params in the path.

    def find_endpoint http_method, path
      self.class.endpoints[http_method].each do |matcher, (endpoint, keys)|
        return [matcher, endpoint, keys] if path =~ matcher
      end

      nil
    end


    ##
    # Process request path and return the matching params.

    def process_path_params path, pattern, keys
      match = pattern.match path
      return Hash.new unless match && !keys.empty?

      values = match.captures.to_a

      if keys.any?
        keys.zip(values).inject({}) do |hash,(k,v)|
          if k == 'splat'
            (hash[k] ||= []) << v
          else
            hash[k] = v
          end

          hash
        end

      elsif values.any?
        {'captures' => values}

      else
        {}
      end
    end


    ##
    # Checks if the given path and params are valid, raises an error if not.
    # Errors raised may be:
    #   Kepi::Api::EndpointUndefined - only when passthrough is not true
    #   Kepi::Endpoint::ParamMissing - required param is missing
    #   Kepi::Endpoint::ParamInvalid - allowed param does not meet criteria
    #   Kepi::Endpoint::ParamUndefined - only if endpoint is strict with params

    def validate path, params
      pattern, endpoint, keys = find_endpoint path

      if endpoint
        params = params.merge process_path_params(path, pattern, keys)
        endpoint.validate params

      elsif !@passthrough
        raise EndpointUndefined, path
      end
    end


    ##
    # Defines globally what to do when not all endpoint conditions are met.
    # By default, returns a 400 error with a json body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_invalid app, env, error
      [INVALID_HTTP_CODE, {'Content-Type' => "application/json"}, error.to_json]
    end


    ##
    # Defines globally what to do when not all endpoint conditions are met.
    # By default, returns a 404 error with a json body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_undefined app, env, error
      [
        UNDEFINED_HTTP_CODE,
        {'Content-Type' => "application/json"},
        error.to_json
      ]
    end


    ##
    # Defines globally what to do when all endpoint conditions are met.
    # By default, forwards the Rack env to the app.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def when_valid app, env
      app.call env
    end
  end
end
