class Kepi

  # Inherited by all Kepi exceptions.
  class Exception < ::Exception; end

  # There was an error with param validation (parent for other param errors).
  class ParamValidationError < Kepi::Exception;
    def initialize endpoint, msg=nil
      super msg
      @endpoint = endpoint
    end

    def to_markup
      msg = "== #{self.class}:\n<b>#{self.message}</b>\n\n---\n"
      msg << @endpoint.to_markup
    end
  end


  # One or more params called are not defined in the endpoint.
  class ParamUndefined < ParamValidationError; end

  # A required param is missing.
  class ParamMissing < ParamValidationError; end

  # An allowed param did not meet the validation criteria.
  class ParamInvalid < ParamValidationError; end
end
