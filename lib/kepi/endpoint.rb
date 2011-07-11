class Kepi

  ##
  # Endpoint param validator.

  class Endpoint

    class Param < Struct.new(:name, :required, :validator, :description)
      def to_markup
        "* #{name.to_s}: #{validator.inspect}\n  #{description}"
      end
    end


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

    # Block to call when validation errors occur.
    attr_accessor :validation_error_handler

    # Block to call when a request for the api docs is made.
    attr_accessor :api_doc_handler

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

    def initialize http_method, path_desc
      @http_method = http_method.to_s.upcase
      @path        = path_desc

      @matcher, @path_keys = self.class.parse_path @path

      @action_handler           = nil
      @error_handler            = nil
      @validation_error_handler = nil
      @api_doc_handler          = nil

      @description            = nil
      @allow_undefined_params = false

      @params = {}

      @path_keys.each{|k| required_param k}
    end


    ##
    # Returns a markup formatted String that describes the endpoint.

    def to_markup
      required = required_params.map{|param| param.to_markup}.join "\n"
      required = "* _none_" if required.empty?

      optional = optional_params.map{|param| param.to_markup}.join "\n"
      optional = "* _none_" if optional.empty?

      <<-STR
= #{@http_method} #{@path}
<b><em>#{@description}</em></b>

=== Strict Params: #{!@allow_undefined_params}

=== Mandatory Params:
#{ required }

=== Optional Params:
#{ optional }
STR
    end


    ##
    # Ensures the params are valid and calls the action_handler.

    def call env, show_api=false
      req = Rack::Request.new env
      req.params.merge! process_path_params(req.path_info)

      return @api_doc_handler.call req, self if show_api

      begin
        validate req.params
        @action_handler.call req, self

      rescue Exception => err
        handler = ParamValidationError === err ?
                    @validation_error_handler  :
                    @error_handler

        raise unless handler
        handler.call req, self, err
      end
    end


    ##
    # Check if a given path matches this endpoint.

    def matches path
      path =~ @matcher
    end


    ##
    # Define a single required param.

    def required_param name, validator=nil, desc=nil
      add_param name, true, validator, desc
    end


    ##
    # Returns array of required params.

    def required_params
      @params.values.select{|param| param.required }
    end


    ##
    # Define a single optional param.

    def optional_param name, validator=nil, desc=nil
      add_param name, false, validator, desc
    end


    ##
    # Returns array of optional params.

    def optional_params
      @params.values.select{|param| !param.required }
    end


    ##
    # Append param to endpoint as required or optional.

    def add_param name, required=false, validator=nil, desc=nil
      name = name.to_s if Symbol === name
      return if name.to_s.empty?

      validator, desc = nil, validator if String === validator
      validator ||= /.+/

      @params[name] = Param.new(name, required, validator, desc)
    end


    ##
    # Converts an endpoint path to its regex matcher.
    # (Thanks Sinatra!)

    def self.parse_path path
      return [path, []] if Regexp === path

      keys = []
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
    # (Thanks Sinatra!)

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
    # Ensure that the params are valid.
    # Raises an error if not.
    #
    # Errors raised may be:
    #   Kepi::Endpoint::ParamMissing - required param is missing
    #   Kepi::Endpoint::ParamInvalid - allowed param does not meet criteria
    #   Kepi::Endpoint::ParamUndefined - only if endpoint is strict with params

    def validate params
      params = params.dup

      @params.each do |mkey, mparam|
        pname, pvalue = params.detect do |pname, pvalue|
                          match_value mparam.name, pname
                        end

        raise ParamMissing, "No param name matches #{mkey.inspect}" if
          !pname && mparam.required

        next if !pname

        raise ParamInvalid,
          "Param #{pname} did not match #{mparam.validator.inspect}" unless
          match_value mparam.validator, pvalue

        params.delete pname
      end

      raise ParamUndefined,
        "Param #{params.keys.map{|k| "'#{k}'"}.join ", "} not supported" unless
          params.empty? || @allow_undefined_params

      true
    end


    ##
    # Match a param key or value to a matcher.

    def match_value matcher, value
      case matcher
      when Class        then matcher === value
      when Range, Array then matcher.include?(value)
      when Regexp       then value.to_s =~ matcher
      when NilClass     then !value.nil? && !value.to_s.empty?
      else
        matcher.to_s == value.to_s
      end
    end


    ##
    # Define an action to call for this endpoint.
    # Block takes a single rack_request argument.

    def on_action &block
      @action_handler = block
    end


    ##
    # Determine what to do if there's an error.
    # Block takes two arguments: rack_request and error.

    def on_error &block
      @error_handler = block
    end


    ##
    # Determine what to do if there's a validation error.
    # Block takes two arguments: rack_request and error.

    def on_validation_error &block
      @validation_error_handler = block
    end


    ##
    # Determine what to do if the request is for the api documentation.
    # Block takes a single rack_request argument.

    def on_api_doc &block
      @api_doc_handler = block
    end
  end
end
