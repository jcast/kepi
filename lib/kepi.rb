class Kepi

  # Version of this gem.
  VERSION = '1.0.0'

  # Inherited by all Kepi exceptions.
  class Exception < ::Exception; end

  require 'kepi/api'
  require 'kepi/endpoint'
end
