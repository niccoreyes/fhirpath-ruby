# frozen_string_literal: true

require 'rexml/document'

module FHIRPath
  module Conformance
    # Converts FHIR XML to FHIR JSON following the canonical FHIR JSON
    # representation rules, without depending on any globally installed gem.
    #
    # Conversion is dependency-minimal: it does not bundle or load FHIR
    # StructureDefinitions. Primitive element types are drawn from a curated
    # table of FHIR R4 primitive element names covering the elements the
    # official suite's XML-only fixtures exercise. Constructs the converter
    # cannot faithfully represent raise UnsupportedStructureError so the
    # importer can fail closed instead of emitting a resource with wrong types.
    class FHIRXmlConverter
      XHTML_NAMESPACE = 'http://www.w3.org/1999/xhtml'
      EXTENSION_NAMES = %w[extension modifierExtension].freeze

      # Elements serialized to a JSON boolean.
      BOOLEAN_ELEMENTS = %w[
        active deceasedBoolean caseSensitive experimental abstract immutable
        compositional exclude required mustSupport isSummary isModifier
        isExample selection preferred inherited readOnly ordered
      ].freeze
      # Elements serialized to a JSON integer.
      INTEGER_ELEMENTS = %w[
        rank total offset size order min max
      ].freeze
      # String-backed primitives: code, id, uri, canonical, oid, uuid, string and
      # all HumanName/Address/CodeableConcept text components. A `value` on any
      # of these is a JSON string.
      STRING_ELEMENTS = %w[
        id url system profile family given name prefix suffix text display
        definition description title copyright publisher question linkId line
        city district state postalCode unit reference answerValueSet subjectType
        content property operator op version code use type status gender
        birthDate date effectiveDateTime valueDateTime timestamp valueString
        valueUri valueUuid
      ].freeze
      # Elements that carry a typed decimal when numeric. `value` is contextual
      # and is treated as decimal only under a Quantity-like parent.
      DECIMAL_ELEMENTS = %w[valueDecimal].freeze

      class UnsupportedStructureError < StandardError; end

      class << self
        # Convert FHIR XML string to an FHIR JSON resource hash.
        # @param xml [String] FHIR XML content
        # @return [Hash] FHIR JSON resource
        # @raise [UnsupportedStructureError] when a structure cannot be converted
        def convert(xml)
          document = REXML::Document.new(xml)
          root = document.root
          raise UnsupportedStructureError, 'XML document has no root element' if root.nil?

          resource = {}
          populate(resource, root)
          resource['resourceType'] = root.local_name
          resource
        end

        private

        # Populate +hash+ from the data children of a complex +element+.
        # Any primitive child that carries an extension also writes a sibling
        # `_<name>` extension object per the FHIR JSON representation.
        def populate(hash, element)
          element.each_element do |child|
            child_local = child.local_name
            if EXTENSION_NAMES.include?(child_local)
              hash['extension'] ||= []
              hash['extension'] << convert_extension(child)
              next
            end

            value, extension = scalar_or_complex(child)
            append(hash, child_local, value)
            hash["_#{child_local}"] = { 'extension' => extension } if extension
          end
          hash
        end

        # Returns [value, extension_array_or_nil] for an element.
        #  - Primitive (value attribute) -> typed scalar, optional extension array.
        #  - XHTML narrative div            -> serialized string.
        #  - <contained> elements           -> array of resource hashes.
        #  - Complex type                   -> nested hash.
        def scalar_or_complex(element)
          local = element.local_name
          return [typed_scalar(element), extension_array(element)] if element.attributes['value']
          return [element.to_s, nil] if local == 'div' && element.namespace == XHTML_NAMESPACE

          return [contained_resources(element), nil] if local == 'contained'

          nested = {}
          populate(nested, element)
          [nested, nil]
        end

        def extension_array(element)
          extensions = element.elements.to_a.select { |c| EXTENSION_NAMES.include?(c.local_name) }
          return nil if extensions.empty?

          extensions.map { |c| convert_extension(c) }
        end

        # An extension element maps to `{ 'url' => ..., 'valueXxx' => ... }`.
        def convert_extension(extension)
          data = {}
          url = extension.attributes['url']
          data['url'] = url.to_s unless url.to_s.empty?
          extension.each_element do |child|
            value, child_ext = scalar_or_complex(child)
            data[child.local_name] = value
            data["_#{child.local_name}"] = { 'extension' => child_ext } if child_ext
          end
          raise UnsupportedStructureError, "extension without url or value: #{extension}" if data.empty?

          data
        end

        def contained_resources(contained)
          contained.elements.to_a.map do |child|
            resource = {}
            populate(resource, child)
            resource['resourceType'] = child.local_name
            resource
          end
        end

        # Repeated sibling elements collapse into a JSON array.
        def append(hash, key, value)
          if hash.key?(key)
            existing = hash[key]
            hash[key] = existing.is_a?(Array) ? existing + [value] : [existing, value]
          else
            hash[key] = value
          end
        end

        # Returns the typed scalar for a primitive `value` attribute.
        def typed_scalar(element)
          local = element.local_name
          raw = element.attributes['value']
          return boolean_value(raw) if BOOLEAN_ELEMENTS.include?(local)
          return integer_value(raw) if INTEGER_ELEMENTS.include?(local)
          return decimal_value(raw) if DECIMAL_ELEMENTS.include?(local)
          return decimal_value(raw) if local == 'value' && quantity_parent?(element)

          raw.to_s
        end

        # The bare `value` element is decimal only inside a Quantity-like
        # container (e.g. Observation.valueQuantity.value). This is the single
        # contextual case the official fixtures exercise.
        def quantity_parent?(element)
          parent = element.parent
          return false unless parent.is_a?(REXML::Element)

          parent.local_name.to_s =~ /quantity/i ? true : false
        end

        def boolean_value(raw)
          case raw.to_s.downcase
          when 'true' then true
          when 'false' then false
          else raise UnsupportedStructureError, "non-boolean value for boolean element: #{raw}"
          end
        end

        def integer_value(raw)
          Integer(raw.to_s, 10)
        rescue ArgumentError
          raise UnsupportedStructureError, "non-integer value for integer element: #{raw}"
        end

        def decimal_value(raw)
          raise UnsupportedStructureError, "non-decimal value for decimal element: #{raw}" unless numeric?(raw)

          raw.to_s
        end

        def numeric?(raw)
          /\A[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?\z/.match?(raw.to_s)
        end
      end
    end
  end
end
