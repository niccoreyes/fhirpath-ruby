# frozen_string_literal: true

require 'json'
require 'rexml/document'

module FHIRPath
  module Conformance
    # Resolves an XML fixture to a verified JSON fixture.
    #
    # The resolver deliberately does NOT trust basename matching alone. A JSON
    # candidate is accepted only when it structurally corresponds to the XML
    # fixture: the root resource type must match and, when both elements carry
    # an `id`, the ids must be equal. This prevents picking a same-named JSON
    # file that is actually a different resource instance.
    #
    # When no verified JSON fixture exists the resolver returns nil and the
    # importer falls back to conversion via FHIRXmlConverter.
    class FixtureResolver
      # @param root [String] root directory to search for fixtures
      def initialize(root:)
        @root = File.expand_path(root)
      end

      # Resolve an XML fixture to its verified JSON representation.
      # @param xml_fixture [String] path to XML fixture relative to root
      # @return [Hash, nil] JSON resource hash, or nil when no verified match
      def resolve(xml_fixture)
        path = resolve_json_path(xml_fixture)
        return nil unless path

        JSON.parse(File.read(path))
      end

      # Resolve an XML fixture to the absolute path of its verified JSON
      # counterpart, or nil when none exists. Used for provenance metadata.
      # @param xml_fixture [String] path to XML fixture relative to root
      # @return [String, nil] absolute path of verified JSON fixture
      def resolve_json_path(xml_fixture)
        xml_path = File.join(@root, xml_fixture)
        return nil unless File.file?(xml_path)

        basename = File.basename(xml_path, '.*')
        parallel = File.join(File.dirname(xml_path), "#{basename}.json")
        candidates = Dir.glob(File.join(@root, '**', "#{basename}.json"))
        candidates << parallel
        candidates.uniq
                  .select { |candidate| File.file?(candidate) }
                  .sort
                  .find { |candidate| structurally_match?(xml_path, candidate) }
      end

      private

      # Verify that +json_path+ is the structured counterpart of +xml_path+.
      # Requires matching resource type and, when both carry an `id`, matching
      # id. This is stronger than a basename heuristic.
      def structurally_match?(xml_path, json_path)
        xml_type = root_resource_type_from_xml(xml_path)
        json = JSON.parse(File.read(json_path))
        return false unless json.is_a?(Hash)
        return false unless json['resourceType'].to_s == xml_type

        xml_id = root_id_from_xml(xml_path)
        json_id = json['id']
        return true if xml_id.nil? || json_id.nil?

        xml_id == json_id
      rescue StandardError
        false
      end

      def root_resource_type_from_xml(xml_path)
        doc = REXML::Document.new(File.read(xml_path))
        doc.root.name.to_s.split(':').last
      end

      def root_id_from_xml(xml_path)
        doc = REXML::Document.new(File.read(xml_path))
        root = doc.root
        return nil unless root

        id_element = root.elements['id']
        return nil unless id_element

        id_element.attributes['value']&.to_s
      end
    end
  end
end
