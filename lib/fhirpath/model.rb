# frozen_string_literal: true

module FHIRPath
  # Adapter boundary for navigating host objects without FHIR dependencies.
  class ModelProvider
    def property(_element, _logical_name)
      raise NotImplementedError
    end

    def root_type(_resource)
      nil
    end
  end

  class PlainModel < ModelProvider
    def root_type(resource)
      return resource['resourceType'] if resource.is_a?(Hash) && resource.key?('resourceType')
      return resource[:resourceType] if resource.is_a?(Hash) && resource.key?(:resourceType)

      resource.class.name
    end

    def property(element, logical_name)
      case element
      when Hash
        return element[logical_name] if element.key?(logical_name)

        symbol = logical_name.to_sym
        element[symbol] if element.key?(symbol)
      when Struct
        symbol = logical_name.to_sym
        element[symbol] if element.members.include?(symbol)
      end
      # No dynamic method dispatch: expression-selected paths must not trigger
      # arbitrary application behavior. Custom object navigation belongs in a
      # ModelProvider.
    end
  end
end
