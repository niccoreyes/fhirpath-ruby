# frozen_string_literal: true

require 'digest'
require_relative 'importer'

module FHIRPath
  module Conformance
    # Imports test cases from the HL7/fhirpath.js test suite as secondary
    # compatibility evidence. fhirpath.js ships spec-style YAML cases under
    # test/cases/*.yaml whose shape closely mirrors the generic importer's YAML
    # support (nested groups, inline + external resources, models, variables,
    # contexts, disabled cases, scalar/list expressions, expected errors).
    #
    # The subclass adds the fhirpath.js-specific concerns that the generic
    # importer must not guess at:
    #   - immutable upstream provenance tagged as `fhirpath.js`;
    #   - per-test release/model selection (r4/plain are supported by the Ruby
    #     engine; r5/stu3/dstu2 cases are retained as explicit not-run records);
    #   - model-specific fixture resolution under test/resources/<model>/ with
    #     no path escape;
    #   - source_model/source_suite fields so provenance survives the schema's
    #     strict model enum;
    #   - deterministic, expression-hashed ids that never depend on descriptions.
    class FHIRPathJSImporter < Importer
      DEFAULT_SUITE = 'HL7/fhirpath.js'
      SUPPORTED_SOURCE_MODELS = %w[r4 plain].freeze

      def initialize(source_root:, suite_path:, suite_commit:, suite: DEFAULT_SUITE, target: '2.0.0',
                     fixture_root: nil, model: 'r4', host_features: Capability.current.host_features,
                     case_ids: nil, load_full_suite: false)
        super(
          source_root: source_root,
          suite_path: suite_path,
          suite_commit: suite_commit,
          suite: suite,
          target: target,
          fixture_root: fixture_root,
          model: model,
          host_features: host_features,
          case_ids: case_ids,
          load_full_suite: load_full_suite
        )
      end

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
          model: manifest.fetch('model', 'r4'),
          host_features: manifest.fetch('host_features', Capability.current.host_features),
          load_full_suite: manifest.fetch('load_full_suite', false)
        )
      end

      private

      # Deterministic ordering is part of the corpus contract: sort by the final
      # id so the validator's ascending-order requirement always holds.
      def import_yaml
        super.sort_by { |record| record['id'] }
      end

      def yaml_record_for(test, expression, subject, group, disabled, ordinal)
        input_fixture = test['inputfile']&.to_s
        source_model = (test['model'] || @model).to_s
        resource, fixture_metadata = fixture_for(input_fixture, subject, source_model)
        record = build_record(
          id: js_case_id(expression, ordinal),
          expression: expression.to_s,
          input_fixture: input_fixture,
          model: normalize_model(source_model),
          capability: group || 'unspecified',
          expected: yaml_expected(test),
          resource: resource,
          variables: deep_copy(test['variables'] || {}),
          origin: origin_for(test['desc'] || js_case_id(expression, ordinal))
        ).merge(fixture_metadata)
        add_yaml_details(record, test)
        add_fhirpath_js_details(record, test, source_model)
        finalize_record(record, fixture_metadata, disabled)
        finalize_model(record, source_model)
      end

      def js_case_id(expression, ordinal)
        "#{@suite_path}:#{ordinal}-#{Digest::SHA256.hexdigest(expression.to_s)[0, 7]}"
      end

      def normalize_model(source_model)
        normalized = source_model.to_s.downcase
        SUPPORTED_SOURCE_MODELS.include?(normalized) ? normalized : 'r4'
      end

      def add_fhirpath_js_details(record, test, source_model)
        record['source_suite'] = 'fhirpath.js'
        record['source_model'] = source_model if test['model']
      end

      def finalize_model(record, source_model)
        normalized = source_model.to_s.downcase
        return record if SUPPORTED_SOURCE_MODELS.include?(normalized)

        mark_not_run(
          record,
          "requires fhirpath.js model '#{source_model}' (engine supports 'r4'/'plain')"
        )
        record
      end

      def origin_for(case_id)
        super.merge('source' => 'fhirpath.js')
      end

      # fhirpath.js stores input fixtures under test/resources/<model>/. When an
      # explicit fixture_root is supplied it is used as the base and the model is
      # appended; otherwise the upstream layout is assumed.
      def fixture_for(input_fixture, fallback = {}, source_model = @model)
        return [deep_copy(fallback || {}), {}] unless input_fixture

        model = source_model.to_s.downcase
        model = 'r4' unless SUPPORTED_SOURCE_MODELS.include?(model)
        read_fixture(input_fixture, fixture_root_for(model))
      end

      def fixture_root_for(model)
        @fixture_root ? File.join(@fixture_root, model) : File.join('test', 'resources', model)
      end

      def read_fixture(input_fixture, model_root)
        path = absolute_path(File.join(model_root, input_fixture))
        # Fall back to the r4 resource tree for cases that omit a model but still
        # reference a resource that exists in the supported tree.
        if !File.file?(path) && !File.basename(model_root).eql?('r4')
          return read_fixture(input_fixture, fixture_root_for('r4'))
        end
        return [nil, { 'not_run_reason' => "fixture not found for #{input_fixture}" }] unless File.file?(path)

        case File.extname(path).downcase
        when '.json'
          [JSON.parse(File.read(path)), { 'fixture_source' => relative_path(path) }]
        else
          raise ArgumentError, "unsupported fhirpath.js fixture format: #{input_fixture}"
        end
      end
    end
  end
end
