require 'rubygems'
require 'rdoc/markup/to_html'

class Kepi

  # Version of this gem.
  VERSION = '1.0.0'

  # Location of this gem
  LIB_ROOT = File.dirname __FILE__

  require 'kepi/errors'
  require 'kepi/api'
  require 'kepi/endpoint'
end
