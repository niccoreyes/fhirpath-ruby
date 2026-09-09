# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/conformance/fhirpath_js_importer'
require 'fhirpath/conformance/corpus_validator'
require 'fileutils'
require 'tmpdir'

class FHIRPathJSImporterTest < Minitest::Test
  JS_SUITE = 'HL7/fhirpath.js'
  JS_COMMIT = '8a4f5deac10bf3b491da139faaa05ef851ecc681'

  def fixtures_root
    File.expand_path('conformance/fhirpath-js', Dir.pwd)
  end

  def import_3_path_selection
    FHIRPath::Conformance::FHIRPathJSImporter.new(
      source_root: fixtures_root,
      suite_path: 'cases/3_path_selection.yaml',
      suite_commit: JS_COMMIT,
      target: '2.0.0',
      model: 'r4',
      load_full_suite: true
    ).import
  end

  def test_imports_inline_subject_and_scalar_expressions
    records = import_3_path_selection
    assert_equal 23, records.length

    resource_id = records.find { |r| r['expression'] == 'Resource.id' }
    refute_nil resource_id
    assert_equal 'r4', resource_id['model']
    assert_equal ['example'], resource_id['expected']
    assert_equal 'Observation', resource_id['resource'] && resource_id['resource']['resourceType']
    assert_equal '3. Path selection', resource_id['capability']

    value_r4 = records.find { |r| r['expression'] == 'Observation.value' && r['description'] =~ /R4 FHIR model/ }
    refute_nil value_r4
    assert_equal ['high'], value_r4['expected']
  end

  def test_scope_3_path_selection_to_supported_r4_model
    records = import_3_path_selection
    unsupported = records.select { |r| r['source_model'] && r['source_model'] != 'r4' }

    # The R5/STU3/DSTU2 model cases must never be silently dropped or mislabelled.
    assert_equal %w[dstu2 r5 stu3], unsupported.map { |r| r['source_model'] }.uniq.sort
    unsupported.each do |record|
      assert_equal 'not-run', record['classification'], "expected not-run for #{record['expression']}"
      assert_match(/requires fhirpath.js model/, record['not_run_reason'])
      # The record's model stays valid for the schema while preserving provenance.
      assert_equal 'r4', record['model']
    end
  end

  def test_models_without_explicit_source_use_default_r4
    records = import_3_path_selection
    no_model = records.find { |r| r['expression'] == 'Observation.value' && r['description'] =~ /without a model/ }
    refute_nil no_model
    assert_equal 'r4', no_model['model']
    assert_nil no_model['source_model']
  end

  def test_records_use_stable_ids_with_expression_hash_and_provenance
    records = import_3_path_selection
    resource_id = records.find { |r| r['expression'] == 'Resource.id' }
    assert_match(%r{\Acases/3_path_selection\.yaml:\d+-[0-9a-f]{7}\z}, resource_id['id'])
    assert_equal 'fhirpath.js', resource_id['source_suite']
    assert_equal JS_SUITE, resource_id['suite']
    assert_equal JS_COMMIT, resource_id['suite_commit']
    assert_equal JS_COMMIT, resource_id.dig('origin', 'suite_commit')
    assert_equal 'cases/3_path_selection.yaml', resource_id.dig('origin', 'path')
    assert_equal 'fhirpath.js', resource_id.dig('origin', 'source')
  end

  def test_corpus_validator_accepts_fhirpath_js_records
    records = import_3_path_selection
    report = FHIRPath::Conformance::CorpusValidator.validate(records)
    assert report[:valid], report[:errors].inspect
  end

  def test_repeated_import_is_deterministic
    first = import_3_path_selection
    second = import_3_path_selection
    assert_equal first, second
    assert_equal FHIRPath::Conformance::CorpusValidator.validate(first)[:digest],
                 FHIRPath::Conformance::CorpusValidator.validate(second)[:digest]
  end

  def test_deep_copies_subjects_to_prevent_cross_test_contamination
    records = import_3_path_selection
    records.first['resource']['id'] = 'mutated'
    other = records.find { |r| r['expression'] != 'Resource.id' }
    assert_equal 'example', other['resource']['id']
  end

  def test_handles_variables_context_and_expected_errors
    Dir.mktmpdir('fhirpath-js-features') do |root|
      File.write(File.join(root, 'features.yaml'), <<~YAML)
        tests:
          - 'group: Variables and contexts':
            - desc: 'Variable bound to scalar'
              expression: '%a - 1'
              variables:
                a: 5
              result: [4]
            - desc: 'Context switching'
              expression: '%context.n1'
              context: 'g1'
              result: [2]
            - desc: 'Expected error'
              expression: '%undefined'
              error: true
            - desc: 'Empty variable'
              expression: '%a'
              variables:
                a: []
              result: []
        subject:
          n1: 1
          g1:
            n1: 2
      YAML

      records = FHIRPath::Conformance::FHIRPathJSImporter.new(
        source_root: root, suite_path: 'features.yaml', suite_commit: JS_COMMIT,
        model: 'r4'
      ).import

      assert_equal 4, records.length
      scalar = records.find { |r| r['expression'] == '%a - 1' }
      assert_equal({ 'a' => 5 }, scalar['variables'])
      assert_equal [4], scalar['expected']

      context = records.find { |r| r['expression'] == '%context.n1' }
      assert_equal 'g1', context['context']

      error = records.find { |r| r['expression'] == '%undefined' }
      assert_equal true, error['error']

      empty = records.find { |r| r['expression'] == '%a' && r['expected'].empty? }
      assert_equal({ 'a' => [] }, empty['variables'])
      assert_equal [], empty['expected']
    end
  end

  def test_expression_lists_become_independent_records
    Dir.mktmpdir('fhirpath-js-lists') do |root|
      File.write(File.join(root, 'lists.yaml'), <<~YAML)
        tests:
          - 'group: Lists':
            - expression:
                - Patient.name.family
                - name.family
              result: [Chalmers]
        subject:
          resourceType: Patient
          name:
            - family: Chalmers
      YAML

      records = FHIRPath::Conformance::FHIRPathJSImporter.new(
        source_root: root, suite_path: 'lists.yaml', suite_commit: JS_COMMIT,
        model: 'r4'
      ).import

      assert_equal 2, records.length
      assert_equal(%w[Patient.name.family name.family], records.map { |r| r['expression'] })
      assert_equal([['Chalmers'], ['Chalmers']], records.map { |r| r['expected'] })
    end
  end

  def test_disabled_cases_are_retained_as_not_run
    Dir.mktmpdir('fhirpath-js-disabled') do |root|
      File.write(File.join(root, 'disabled.yaml'), <<~YAML)
        tests:
          - 'group: Disabled':
            - desc: 'Disabled test'
              expression: Resource.name
              result: ['should']
              disable: true
      YAML

      records = FHIRPath::Conformance::FHIRPathJSImporter.new(
        source_root: root, suite_path: 'disabled.yaml', suite_commit: JS_COMMIT,
        model: 'r4'
      ).import

      assert_equal 1, records.length
      assert_equal 'not-run', records.first['classification']
      assert_match(/disabled/, records.first['not_run_reason'])
    end
  end

  def test_resolves_model_specific_input_fixtures_and_deep_copies_them
    Dir.mktmpdir('fhirpath-js-inputfile') do |root|
      resources = File.join(root, 'test', 'resources', 'r4')
      FileUtils.mkdir_p(resources)
      File.write(File.join(resources, 'patient.json'),
                 { 'resourceType' => 'Patient', 'id' => 'p1' }.to_json)
      File.write(File.join(root, 'input.yaml'), <<~YAML)
        tests:
          - 'group: Input file':
            - desc: 'Load from resources/r4'
              inputfile: patient.json
              model: r4
              expression: Patient.id
              result: ['p1']
      YAML

      records = FHIRPath::Conformance::FHIRPathJSImporter.new(
        source_root: root, suite_path: 'input.yaml', suite_commit: JS_COMMIT,
        model: 'r4'
      ).import

      assert_equal 1, records.length
      assert_equal({ 'resourceType' => 'Patient', 'id' => 'p1' }, records.first['resource'])
      assert_match(%r{\A test/resources/r4/patient\.json\z}x, records.first['fixture_source'])
    end
  end

  def test_import_updates_source_model_provenance_only
    Dir.mktmpdir('fhirpath-js-model') do |root|
      File.write(File.join(root, 'models.yaml'), <<~YAML)
        tests:
          - 'group: Models':
            - desc: 'R5 case'
              expression: Observation.value
              result: ['high']
              model: r5
      YAML

      records = FHIRPath::Conformance::FHIRPathJSImporter.new(
        source_root: root, suite_path: 'models.yaml', suite_commit: JS_COMMIT,
        model: 'r4'
      ).import

      assert_equal 1, records.length
      assert_equal 'r5', records.first['source_model']
      assert_equal 'r4', records.first['model']
      assert_equal 'not-run', records.first['classification']
      assert_match(/requires fhirpath.js model 'r5'/, records.first['not_run_reason'])
    end
  end
end
