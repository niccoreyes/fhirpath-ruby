# frozen_string_literal: true

module FHIRPath
  module FHIR
    module R4
      # Dependency-free adapter for the FHIR R4 JSON representation.
      #
      # The evaluator only knows the ModelProvider protocol. FHIR release
      # metadata stays in this adapter so a different release can provide its
      # own provider without changing the language core.
      class ModelProvider < FHIRPath::ModelProvider
        RELEASE = 'R4'
        VERSION = '4.0.1'

        CHOICE_FIELDS = {
          'Observation' => {
            'value' => %w[
              valueQuantity valueCodeableConcept valueString valueBoolean
              valueInteger valueRange valueRatio valueSampledData valueTime
              valueDateTime valuePeriod
            ].freeze
          }
        }.freeze
        CHOICE_TYPES = {
          'Observation' => {
            'value' => %w[
              Quantity CodeableConcept string boolean integer Range Ratio SampledData time dateTime Period
            ].freeze
          }
        }.freeze

        def root_type(resource)
          return resource['resourceType'] if resource.is_a?(Hash) && resource.key?('resourceType')
          return resource[:resourceType] if resource.is_a?(Hash) && resource.key?(:resourceType)

          resource.class.name
        end

        def property(element, logical_name)
          return direct_property(element, logical_name) if direct_property?(element, logical_name)

          choice_names = CHOICE_FIELDS.fetch(root_type(element).to_s, {}).fetch(logical_name.to_s, [])
          choice_names.each do |choice_name|
            return element[choice_name] if element.is_a?(Hash) && element.key?(choice_name)
            return element[choice_name.to_sym] if element.is_a?(Hash) && element.key?(choice_name.to_sym)
          end
          nil
        end

        def choice_types(parent_type, logical_name)
          CHOICE_TYPES.fetch(parent_type.to_s, {}).fetch(logical_name.to_s, []).freeze
        end

        def type_of(element)
          root_type(element)
        end

        private

        def direct_property?(element, logical_name)
          element.is_a?(Hash) &&
            (element.key?(logical_name.to_s) || element.key?(logical_name.to_sym))
        end

        def direct_property(element, logical_name)
          return element[logical_name.to_s] if element.key?(logical_name.to_s)

          element[logical_name.to_sym]
        end
      end
    end
  end
end
