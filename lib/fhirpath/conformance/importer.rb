# frozen_string_literal: true

require 'json'
require 'rexml/document'

module FHIRPath
  module Conformance
    # Imports a selected, pinned subset of the official XML shared suite.
    # The importer is deliberately Ruby-only so it is safe to use in tests and
    # release checks without installing a second language runtime.
    class Importer
      DEFAULT_SUITE = 'FHIR/fhir-test-cases'

      def self.from_manifest(path, source_root: nil)
        manifest = JSON.parse(File.read(path))
        root = source_root || File.dirname(path)
        new(
          source_root: root,
          suite_path: manifest.fetch('source'),
          fixture_root: manifest['fixture_root'],
          suite: manifest.fetch('suite', DEFAULT_SUITE),
          suite_commit: manifest.fetch('suite_commit'),
          target: manifest.fetch('target'),
          model: manifest.fetch('model', 'plain'),
          case_ids: manifest['cases']
        )
      end

      def initialize(source_root:, suite_path:, suite_commit:, suite: DEFAULT_SUITE, target: '2.0.0',
                     fixture_root: nil, model: 'plain', case_ids: nil)
        @source_root = File.expand_path(source_root)
        @suite_path = relative_path(suite_path)
        @fixture_root = fixture_root && relative_path(fixture_root)
        @suite = suite.to_s.freeze
        @suite_commit = suite_commit.to_s.freeze
        @target = target.to_s.freeze
        @model = model.to_s.freeze
        @case_ids = case_ids&.map(&:to_s)&.freeze
        raise ArgumentError, 'suite_commit must not be empty' if @suite_commit.empty?
        raise ArgumentError, 'target must not be empty' if @target.empty?
      end

      def import
        document = REXML::Document.new(File.read(absolute_path(@suite_path)))
        tests = document.root.elements.to_a('group/test')
        selected = select_tests(tests)
        selected.map { |test| record_for(test) }
      end

      private

      def select_tests(tests)
        return tests unless @case_ids

        by_id = tests.to_h { |test| [test.attributes.fetch('name').to_s, test] }
        @case_ids.map do |case_id|
          by_id.fetch(case_id) { raise ArgumentError, "case not found in suite: #{case_id}" }
        end
      end

      def record_for(test)
        case_id = test.attributes.fetch('name').to_s
        input_fixture = test.attributes['inputfile']&.to_s
        resource = input_fixture ? read_fixture(input_fixture) : {}
        expression = test.elements['expression']&.text.to_s.strip
        expected = test.elements.to_a('output').map { |output| parse_output(output) }
        expected_error = parse_error(test)
        group = test.parent.attributes['name'].to_s
        origin = {
          'suite' => @suite,
          'suite_commit' => @suite_commit,
          'case' => case_id,
          'path' => @suite_path
        }

        {
          'id' => case_id,
          'suite' => @suite,
          'suite_commit' => @suite_commit,
          'expression' => expression,
          'input_fixture' => input_fixture && fixture_path(input_fixture),
          'model' => @model,
          'target' => @target,
          'capability' => group,
          'expected' => expected,
          'resource' => resource,
          'variables' => {},
          'origin' => origin
        }.tap do |record|
          record['error'] = expected_error if expected_error
        end
      end

      def parse_error(test)
        error = test.elements['error']
        return unless error

        data = {}
        %w[class code].each do |key|
          data[key] = error.attributes[key].to_s if error.attributes[key]
        end
        data['class'] ||= error.text.to_s.strip unless error.text.to_s.strip.empty?
        data.empty? ? nil : data
      end

      def parse_output(output)
        value = output.text.to_s
        case output.attributes['type'].to_s
        when 'boolean' then value.strip.casecmp('true').zero?
        when 'integer' then Integer(value.strip, 10)
        when 'decimal' then value.strip
        when 'string', 'code', 'id', 'uri', 'url', 'markdown' then value
        else
          { '$type' => output.attributes['type'], 'value' => value }
        end
      end

      def read_fixture(input_fixture)
        path = absolute_path(fixture_path(input_fixture))
        case File.extname(path).downcase
        when '.json'
          JSON.parse(File.read(path))
        when '.xml'
          xml_fixture_to_hash(REXML::Document.new(File.read(path)).root)
        else
          raise ArgumentError, "unsupported fixture format: #{input_fixture}"
        end
      end

      def xml_fixture_to_hash(root)
        value = element_value(root)
        value.is_a?(Hash) ? value.merge('resourceType' => local_name(root.name)) : value
      end

      def element_value(element)
        children = element.elements.to_a
        return element.attributes['value'] if children.empty? && element.attributes['value']
        return nil if children.empty?

        children.each_with_object({}) do |child, result|
          key = local_name(child.name)
          value = element_value(child)
          result[key] = if result.key?(key)
                          Array(result[key]) << value
                        else
                          value
                        end
        end
      end

      def local_name(name)
        name.to_s.split(':').last
      end

      def fixture_path(input_fixture)
        relative_path(File.join(@fixture_root || File.dirname(@suite_path), input_fixture))
      end

      def relative_path(path)
        expanded = File.expand_path(path.to_s, @source_root)
        prefix = "#{@source_root}#{File::SEPARATOR}"
        return expanded.delete_prefix(prefix) if expanded.start_with?(prefix)
        return '.' if expanded == @source_root

        raise ArgumentError, "path escapes source root: #{path}"
      end

      def absolute_path(path)
        File.join(@source_root, path)
      end
    end
  end
end
