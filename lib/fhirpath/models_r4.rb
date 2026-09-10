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
          },
          'Medication' => {
            'medication' => %w[
              medicationCodeableConcept medicationReference
            ].freeze
          },
          'Condition' => {
            'clinicalStatus' => %w[
              clinicalStatusCodeableConcept clinicalStatusCoding
            ].freeze,
            'verificationStatus' => %w[
              verificationStatusCodeableConcept verificationStatusCoding
            ].freeze
          },
          'Procedure' => {
            'outcome' => %w[
              outcomeCodeableConcept outcomeReference
            ].freeze,
            'indication' => %w[
              indicationCodeableConcept indicationReference
            ].freeze
          },
          'DiagnosticReport' => {
            'category' => %w[
              categoryCodeableConcept categoryCoding
            ].freeze,
            'code' => %w[
              codeCodeableConcept codeCoding
            ].freeze
          }
        }.freeze
        CHOICE_TYPES = {
          'Observation' => {
            'value' => %w[
              Quantity CodeableConcept string boolean integer Range Ratio SampledData time dateTime Period
            ].freeze
          },
          'Medication' => {
            'medication' => %w[
              CodeableConcept Reference
            ].freeze
          },
          'Condition' => {
            'clinicalStatus' => %w[
              CodeableConcept Coding
            ].freeze,
            'verificationStatus' => %w[
              CodeableConcept Coding
            ].freeze
          },
          'Procedure' => {
            'outcome' => %w[
              CodeableConcept Reference
            ].freeze,
            'indication' => %w[
              CodeableConcept Reference
            ].freeze
          },
          'DiagnosticReport' => {
            'category' => %w[
              CodeableConcept Coding
            ].freeze,
            'code' => %w[
              CodeableConcept Coding
            ].freeze
          }
        }.freeze

        # Choice variant names whose declared FHIR type is Quantity.
        QUANTITY_ELEMENT_NAMES = CHOICE_FIELDS.flat_map do |type, fields|
          fields.flat_map do |logical_name, names|
            types = CHOICE_TYPES.fetch(type, {}).fetch(logical_name, [])
            names.each_with_index.select { |_name, index| types[index] == 'Quantity' }.map(&:first)
          end
        end.uniq.freeze

        def root_type(resource)
          return resource['resourceType'] if resource.is_a?(Hash) && resource.key?('resourceType')
          return resource[:resourceType] if resource.is_a?(Hash) && resource.key?(:resourceType)

          resource.class.name
        end

        def property(element, logical_name)
          return quantity_member(element, logical_name) if element.is_a?(FHIRPath::Quantity)
          return quantity_element(element, logical_name) if quantity_element_name?(logical_name)
          return direct_property(element, logical_name) if direct_property?(element, logical_name)

          choice_property(element, logical_name)
        end

        def choice_property(element, logical_name)
          return nil unless element.is_a?(Hash)

          choice_names = CHOICE_FIELDS.fetch(root_type(element).to_s, {}).fetch(logical_name.to_s, [])
          choice_name = choice_names.find do |name|
            element.key?(name) || element.key?(name.to_sym)
          end
          return nil unless choice_name
          return quantity_element(element, choice_name) if quantity_element_name?(choice_name)

          element.key?(choice_name) ? element[choice_name] : element[choice_name.to_sym]
        end

        # FHIR `Quantity` elements are surfaced as FHIRPath Quantity values so
        # they can be compared and combined with quantity literals. An element
        # whose unit is not a supported UCUM atom is left as its raw JSON form
        # rather than being presented as a dimensionless Quantity.
        def quantity_element(element, logical_name)
          value = hash_field(element, logical_name)
          return nil unless value.is_a?(Hash)

          quantity_from(value) || value
        end

        def quantity_from(element)
          unit = element_code(element)
          return nil if unit.to_s.empty?

          FHIRPath::Quantity.new(
            value: hash_field(element, 'value'),
            unit: unit,
            system: hash_field(element, 'system'),
            code: unit
          )
        rescue ArgumentError
          nil
        end

        # FHIR Quantity unit for UCUM purposes: the coded form when present,
        # otherwise the human-readable unit.
        def element_code(element)
          code = hash_field(element, 'code')
          code.to_s.empty? ? hash_field(element, 'unit') : code
        end

        # Reads a FHIR JSON element by name, accepting string and symbol keys.
        def hash_field(element, name)
          return nil unless element.is_a?(Hash)

          element.key?(name.to_s) ? element[name.to_s] : element[name.to_sym]
        end

        # Member access on a mapped Quantity (`Observation.value.unit`).
        QUANTITY_MEMBERS = {
          'value' => :value, 'unit' => :unit, 'system' => :system, 'code' => :code
        }.freeze

        def quantity_member(quantity, logical_name)
          member = QUANTITY_MEMBERS[logical_name.to_s]
          member && quantity.public_send(member)
        end

        # Choice variant names declared as FHIR Quantity, so navigating them
        # directly (Observation.valueQuantity) matches choice resolution.
        def quantity_element_name?(logical_name)
          QUANTITY_ELEMENT_NAMES.include?(logical_name.to_s)
        end

        def choice_types(parent_type, logical_name)
          CHOICE_TYPES.fetch(parent_type.to_s, {}).fetch(logical_name.to_s, []).freeze
        end

        # Model type name of the choice variant that `property` resolves for
        # +logical_name+ on +element+, using the same key order as CHOICE_FIELDS
        # so the concrete variant maps to its declared type (valueQuantity ->
        # Quantity, valueString -> string). Returns nil when no choice variant
        # is present or the property is not a declared choice.
        def property_logical_type(element, logical_name)
          choice_names = CHOICE_FIELDS.fetch(root_type(element).to_s, {}).fetch(logical_name.to_s, [])
          return nil if choice_names.empty?

          index = choice_names.index do |choice_name|
            element.is_a?(Hash) &&
              (element.key?(choice_name) || element.key?(choice_name.to_sym))
          end
          return nil if index.nil?

          CHOICE_TYPES.fetch(root_type(element).to_s, {}).fetch(logical_name.to_s, [])[index]
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
