# frozen_string_literal: true

module FHIRPath
  # Named, versioned model providers available to the public API.
  module ModelRegistry
    module_function

    def fetch(release)
      case release.to_s.downcase
      when 'r4', '4', '4.0.1'
        FHIR::R4::ModelProvider.new
      else
        raise ArgumentError, "unknown FHIR model release: #{release}"
      end
    end
  end
end
