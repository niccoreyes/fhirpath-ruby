# frozen_string_literal: true

require_relative 'fhirpath/version'

# Namespace for the Ruby FHIRPath implementation.
#
# Parsing, evaluation, and FHIR model integration will be added behind this
# public namespace after the architecture review is complete.
module FHIRPath
  class << self
    # Returns the library version.
    def version
      VERSION
    end
  end
end
