class Kepi

  ##
  # Endpoint param validator.

  class Endpoint

    # There was an error with param validation (parent for other param errors).
    class ParamValidationError < Kepi::Exception; end

    # One or more params called are not defined in the endpoint.
    class ParamUndefined < ParamValidationError; end

    # A required param is missing.
    class ParamMissing < ParamValidationError; end

    # An allowed param did not meet the validation criteria.
    class ParamInvalid < ParamValidationError; end


    # Don't take into account given params that aren't defined in the endpoint.
    attr_accessor :allow_undefined_params

    # The description of the endpoint.
    attr_accessor :description

    # Block to call when validation succeeds.
    attr_accessor :action_handler

    # Block to call when errors occur.
    attr_accessor :error_handler

    # Path descriptor of endpoint.
    attr_reader :path

    # HTTP method this endpoint responds to.
    attr_reader :http_method

    # The path regexp matcher to check if this is the correct endpoint.
    attr_reader :matcher

    # Keys for params to be retrieved from the path.
    attr_reader :path_keys


    ##
    # Create a new Endpoint param validator.

    def initalize http_method, path_desc
      @http_method = http_method
      @path        = path_desc

      @matcher, @path_keys = parse_path @path

      @action_handler         = nil
      @error_handler          = nil
      @description            = nil
      @allow_undefined_params = false

      @when_invalid = nil
      @when_valid   = nil

      @mandatory_params = []
      @optional_params  = []
    end


    ##
    # Check if a given path matches this endpoint.

    def matches path
      path =~ @matcher
    end


    ##
    # Define mandatory params. Takes an array and/or a hash that
    # defines how the param must be validated:
    #   e.mandatory_params :search_terms  => String,
    #                      /^geo|g$/      => String,
    #                      :refinements   => %w{valid1 valid2 valid3}
    #                      :limit         => [1...100]

    def mandatory_params *params
      #TODO: implement
      params.each do |name|
        if Hash === name
          
          p.each do |name, val|
          end
        end
      end
    end


    ##
    # Converts an endpoint path to its regex matcher.
    # (Thanks Sinatra!)

    def parse_path path
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
    # Process request path and return the matching params.

    def process_path_params path
      match  = @matcher.match path
      values = match.captures.to_a

      if @path_keys.any?
        @path_keys.zip(values).inject({}) do |hash,(k,v)|
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
    # Ensures the params are valid and calls the action_handler.

    def call req
      req.params.merge! process_path_params(req.path_info)
      validate req.params

      @action_handler.call(req) if @action_handler
    end


    ##
    # Ensure that the params are valid.
    # Raises an error if not.
    #
    # Errors raised may be:
    #   Kepi::Endpoint::ParamMissing - required param is missing
    #   Kepi::Endpoint::ParamInvalid - allowed param does not meet criteria
    #   Kepi::Endpoint::ParamUndefined - only if endpoint is strict with params

    def validate params
      #TODO: implement
    end


    ##
    # Define an action to call for this endpoint.
    # Block takes a single rack_request argument.

    def action &block
      @action_handler = block
    end


    ##
    # Determine what to do if there's an error.
    # Block takes two arguments: rack_request and error.

    def error &block
      @error_handler = block
    end
  end
end
