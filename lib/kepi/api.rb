class Kepi

  ##
  # Inherit the Api class to define a new service api. The child class
  # may then be used as a standard Rack middleware.

  class Api

    # Raised when an endpoint is called but not defined
    class EndpointUndefined < Kepi::Exception; end

    # Default content-type to return.
    DEFAULT_CONTENT_TYPE = "text/html"

    # HTTP code when api and endpoint action have not been defined.
    HTTP_NO_CONTENT = 204

    # HTTP error code to use when validation fails.
    HTTP_INVALID = 400

    # HTTP error code to use when endpoint is undefined.
    HTTP_UNDEFINED = 404

    # HTTP error code for uncaught exceptions.
    HTTP_INTERNAL_ERROR = 500


    class << self
      # The path suffix to look for to return the api documentation.
      # Defaults to /api
      attr_accessor :api_doc_suffix

      # The path to get to the root of the api documentation.
      # Defaults to /api
      attr_accessor :api_doc_path

      # Global setting to not raise errors when unexpected params are given.
      # Defaults to false. May be overridden by each endpoint individually.
      attr_accessor :allow_undefined_params
    end


    def self.inherited subclass
      subclass.api_doc_suffix         = "/api"
      subclass.api_doc_path           = "/api"
      subclass.allow_undefined_params = false
    end


    ##
    # Define a new endpoint for this Api class.
    # If block is given, passes it the newly created Endpoint instance.

    def self.endpoint http_method, path
      http_method  = http_method.to_s.upcase
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


    # If used as middleware, the app given from the Rack stack.
    attr_reader :app


    ##
    # Initialize with the provided Rack app object.
    # May be used as full application by omitting the app argument.

    def initialize app=nil
      @app = app

      self.class.endpoints.values.flatten.each do |endpoint|
        endpoint.action_handler           ||= method :default_action
        endpoint.api_doc_handler          ||= method :default_api_doc
        endpoint.error_handler            ||= method :default_error
        endpoint.validation_error_handler ||= method :default_validation_error
      end
    end


    ##
    # Call the api + endpoint stack.

    def call env
      #load File.join(LIB_ROOT, "kepi/api.rb")
      path, show_api = parse_path_api env['PATH_INFO']
      endpoint       = find_endpoint env['REQUEST_METHOD'], path

      if endpoint
        env['PATH_INFO'] = path
        response(*endpoint.call(env, show_api))

      elsif env['PATH_INFO'] == self.class.api_doc_path
        api_response

      elsif @app
        @app.call env

      else
        undefined_response env
      end
    end


    ##
    # Figure out if the given path should return the api docs for that path.

    def parse_path_api path
      return path unless path =~ %r{(.*)#{self.class.api_doc_suffix}$}i
      [$1, true]
    end


    ##
    # Returns a markup String that describes the api.

    def to_markup
      <<-STR
= #{self.class} Api

#{sorted_endpoints.map do |e|
    "=== #{e.http_method} #{e.path}\n\n" +
    "<em>#{e.description}</em>\n\n" +
    "Details at link:#{e.path}#{self.class.api_doc_suffix}"
  end.join "\n\n" }
      STR
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
    # Returns an Array of endpoints sorted by http method and path.

    def sorted_endpoints
      endpoints = self.class.endpoints.values.flatten

      endpoints.sort do |x,y|
        "#{x.path} #{x.http_method}" <=> "#{y.path} #{y.http_method}"
      end
    end


    ##
    # Defines the default behavior when endpoint conditions are met.
    # By default, forwards the Rack env to the app if used as middleware,
    # otherwise returns a blank Rack response Array.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def default_action req, endpoint
      return @app.call req.env if @app
      response HTTP_NO_CONTENT
    end


    ##
    # Default response to use when the api doc is requested.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def default_api_doc req, endpoint
      response api_html(endpoint.to_markup)
    end


    ##
    # Default endpoint error handler.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def default_error req, endpoint, error
      msg = "= #{error.class}:\n<b>#{error.message}</b>\n\n"
      msg << error.backtrace

      response HTTP_INTERNAL_ERROR, api_html(msg)
    end


    ##
    # Defines by default what to do when not all endpoint conditions are met.
    # By default, returns a 400 error with the error and endpoint
    # markup string as text in the body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def default_validation_error req, endpoint, error
      msg = "= #{error.class}:\n<b>#{error.message}</b>\n\n---\n"
      msg << endpoint.to_markup
      msg << "\n\n---\n#{to_markup}"

      response HTTP_INVALID, api_html(msg)
    end


    API_CSS = File.read File.join(LIB_ROOT, "rdoc.css")

    ##
    # Wraps the given String in the api doc html layout.

    def api_html page
      <<-STR
<html>
  <head>
    <title>#{self.class} Api Documentation</title>
    <style>
#{API_CSS}
    </style>
  </head>
  <body class="indexpage">
    <div>
    #{RDoc::Markup::ToHtml.new.convert page.to_s}
    </div>
  </body>
</html>
      STR
    end


    ##
    # Builds a default response Array, given a status code and http body String.

    def response code=nil, body=nil, headers=nil
      args = [code, body, headers].compact

      headers = {'Content-Type' => DEFAULT_CONTENT_TYPE}
      code    = 200
      body    = ""

      args.each do |arg|
        case arg
        when Hash    then headers.merge!(arg)
        when String  then body    = arg
        when Integer then code    = arg
        end
      end

      [code, headers, body]
    end


    ##
    # Defines globally what to do when not all endpoint conditions are met.
    # By default, returns a 404 error with a html body.
    #
    # Must return a valid Rack response Array. May be overridden by child class.

    def undefined_response env
      msg = "= Endpoint Undefined:\n"
      msg << "<b>No endpoint responded to #{env['PATH_INFO']}</b>\n\n---\n"
      msg << to_markup

      response HTTP_UNDEFINED, api_html(msg)
    end


    ##
    # The main API html response.

    def api_response
      response api_html(to_markup)
    end
  end
end
