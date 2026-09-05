# frozen_string_literal: true

require 'json'
require 'rexml/document'
require 'yaml'
require_relative '../capability'

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
          host_features: manifest.fetch('host_features', Capability.current.host_features),
          case_ids: manifest['cases']
        )
      end

      def initialize(source_root:, suite_path:, suite_commit:, suite: DEFAULT_SUITE, target: '2.0.0',
                     fixture_root: nil, model: 'plain', host_features: Capability.current.host_features, case_ids: nil)
        @source_root = File.expand_path(source_root)
        @suite_path = relative_path(suite_path)
        @fixture_root = fixture_root && relative_path(fixture_root)
        @suite = suite.to_s.freeze
        @suite_commit = suite_commit.to_s.freeze
        @target = target.to_s.freeze
        @model = model.to_s.freeze
        @host_features = Array(host_features).map(&:to_s).freeze
        @case_ids = case_ids&.map(&:to_s)&.freeze
        validate_options
      end

      def import
        case File.extname(@suite_path).downcase
        when '.xml' then import_xml
        when '.yaml', '.yml' then import_yaml
        else raise ArgumentError, "unsupported suite format: #{@suite_path}"
        end
      end

      private

      def validate_options
        raise ArgumentError, 'suite_commit must not be empty' if @suite_commit.empty?
        raise ArgumentError, 'target must not be empty' if @target.empty?
      end

      def import_xml
        document = REXML::Document.new(File.read(absolute_path(@suite_path)))
        tests = document.root.elements.to_a('group/test')
        select_tests(tests).map { |test| record_for(test) }
      end

      def import_yaml
        document = YAML.safe_load_file(absolute_path(@suite_path), permitted_classes: [], aliases: false)
        subject = deep_copy(document['subject']) if document.is_a?(Hash)
        ordinal = 0
        records = []
        flatten_yaml_tests(document.fetch('tests')).each do |test, group, disabled|
          expressions = test['expression'].is_a?(Array) ? test['expression'] : [test['expression']]
          expressions.each do |expression|
            ordinal += 1
            records << yaml_record_for(test, expression, subject, group, disabled, ordinal)
          end
        end
        records
      end

      def flatten_yaml_tests(value, group = nil, disabled: false, records: [])
        Array(value).each { |entry| flatten_yaml_entry(entry, group, disabled, records) }
        records
      end

      def flatten_yaml_entry(entry, group, disabled, records)
        raise ArgumentError, 'YAML suite entries must be mappings' unless entry.is_a?(Hash)

        group_key = entry.keys.find { |key| key.to_s.start_with?('group') }
        if group_key
          group_name = group_key.to_s.delete_prefix('group:').strip
          group_disabled = disabled || entry['disable'] == true
          flatten_yaml_tests(entry.fetch(group_key), group_name, disabled: group_disabled, records: records)
        elsif entry.key?('expression')
          records << [entry, group, disabled || entry['disable'] == true]
        end
      end

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
        resource, fixture_metadata = fixture_for(input_fixture)
        record = build_record(
          id: case_id,
          expression: test.elements['expression']&.text.to_s.strip,
          input_fixture: input_fixture,
          model: @model,
          capability: test.parent.attributes['name'].to_s,
          expected: expected_outputs(test),
          resource: resource,
          variables: {},
          origin: origin_for(case_id)
        ).merge(fixture_metadata)
        add_field(record, 'error', parse_error(test))
        finalize_record(record, fixture_metadata, disabled_test?(test))
      end

      def yaml_record_for(test, expression, subject, group, disabled, ordinal)
        input_fixture = test['inputfile']&.to_s
        resource, fixture_metadata = fixture_for(input_fixture, subject)
        case_id = "#{@suite_path}:#{ordinal}"
        record = build_record(
          id: case_id,
          expression: expression.to_s,
          input_fixture: input_fixture,
          model: (test['model'] || @model).to_s,
          capability: group || 'unspecified',
          expected: yaml_expected(test),
          resource: resource,
          variables: deep_copy(test['variables'] || {}),
          origin: origin_for(test['desc'] || case_id)
        ).merge(fixture_metadata)
        add_yaml_details(record, test)
        finalize_record(record, fixture_metadata, disabled)
      end

      def add_yaml_details(record, test)
        add_field(record, 'description', test['desc']&.to_s)
        add_field(record, 'context', test['context']&.to_s)
        add_true_field(record, 'error', test['error'] == true)
      end

      def build_record(id:, expression:, input_fixture:, model:, capability:, expected:, resource:, variables:, origin:)
        {
          'id' => id,
          'suite' => @suite,
          'suite_commit' => @suite_commit,
          'expression' => expression,
          'input_fixture' => normalized_fixture_path(input_fixture),
          'model' => model,
          'host_features' => @host_features,
          'target' => @target,
          'capability' => capability,
          'expected' => expected,
          'resource' => resource,
          'variables' => variables,
          'origin' => origin
        }
      end

      def expected_outputs(test)
        test.elements.to_a('output').map { |output| parse_output(output) }
      end

      def yaml_expected(test)
        test.key?('result') ? normalize_yaml_result(test['result']) : []
      end

      def origin_for(case_id)
        {
          'suite' => @suite,
          'suite_commit' => @suite_commit,
          'case' => case_id,
          'path' => @suite_path
        }
      end

      def add_field(record, key, value)
        record[key] = value unless value.nil?
        record
      end

      def add_true_field(record, key, condition)
        record[key] = true if condition
        record
      end

      def finalize_record(record, fixture_metadata, disabled)
        mark_not_run(record, fixture_metadata['not_run_reason']) if fixture_metadata['not_run_reason']
        mark_not_run(record, 'disabled by source suite') if disabled
        record
      end

      def normalize_yaml_result(result)
        result.is_a?(Array) ? deep_copy(result) : [deep_copy(result)]
      end

      def disabled_test?(test)
        test.attributes['disabled'].to_s == 'true' || test.attributes['disable'].to_s == 'true'
      end

      def mark_not_run(record, reason)
        record['classification'] = 'not-run'
        record['not_run_reason'] = reason
        record['resource'] = nil if reason.include?('matching JSON fixture')
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

      def fixture_for(input_fixture, fallback = {})
        return [deep_copy(fallback || {}), {}] unless input_fixture

        read_fixture(input_fixture)
      end

      def normalized_fixture_path(input_fixture)
        input_fixture && fixture_path(input_fixture)
      end

      def read_fixture(input_fixture)
        path = absolute_path(fixture_path(input_fixture))
        case File.extname(path).downcase
        when '.json'
          [JSON.parse(File.read(path)), { 'fixture_source' => fixture_path(input_fixture) }]
        when '.xml'
          json_path = matching_json_fixture(path)
          unless json_path
            return [nil, {
              'not_run_reason' => "no verified matching JSON fixture for #{fixture_path(input_fixture)}"
            }]
          end

          [JSON.parse(File.read(json_path)), { 'fixture_source' => relative_path(json_path) }]
        else
          raise ArgumentError, "unsupported fixture format: #{input_fixture}"
        end
      end

      def matching_json_fixture(xml_path)
        candidates = [xml_path.sub(/\.xml\z/i, '.json')]
        basename = File.basename(xml_path, File.extname(xml_path))
        search_root = absolute_path(@fixture_root || File.dirname(@suite_path))
        candidates.concat(Dir.glob(File.join(search_root, '**', "#{basename}.json")))
        candidates.uniq.select { |candidate| File.file?(candidate) }.sort.find do |candidate|
          resource = JSON.parse(File.read(candidate))
          resource.is_a?(Hash) && resource['resourceType'].to_s == xml_resource_type(xml_path)
        rescue JSON::ParserError
          false
        end
      end

      def xml_resource_type(path)
        REXML::Document.new(File.read(path)).root.name.to_s.split(':').last
      end

      def deep_copy(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, item), copy| copy[deep_copy(key)] = deep_copy(item) }
        when Array
          value.map { |item| deep_copy(item) }
        else
          value
        end
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
