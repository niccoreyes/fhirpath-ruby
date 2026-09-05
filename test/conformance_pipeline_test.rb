# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/vector_runner'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'tempfile'

class FHIRPathConformancePipelineTest < Minitest::Test
  def test_importer_reads_selected_official_xml_cases_with_independent_provenance
    Dir.mktmpdir('fhirpath-import') do |root|
      source = File.join(root, 'r4', 'fhirpath', 'tests.xml')
      fixture = File.join(root, 'r4', 'patient.json')
      FileUtils.mkdir_p(File.dirname(source))
      File.write(source, <<~XML)
        <tests name="FHIRPathTestSuite" reference="http://hl7.org/fhirpath|2.0.0">
          <group name="core">
            <test name="case-two" inputfile="patient.json">
              <expression>2 + 2</expression>
              <output type="integer">4</output>
            </test>
            <test name="not-selected">
              <expression>1 + 1</expression>
              <output type="integer">2</output>
            </test>
          </group>
        </tests>
      XML
      File.write(fixture, { 'resourceType' => 'Patient' }.to_json)

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'r4/fhirpath/tests.xml',
        suite: 'FHIR/fhir-test-cases',
        suite_commit: 'abc123',
        target: '2.0.0',
        fixture_root: 'r4',
        case_ids: ['case-two']
      ).import

      assert_equal 1, records.length
      record = records.first
      assert_equal 'FHIR/fhir-test-cases', record['suite']
      assert_equal 'abc123', record['suite_commit']
      assert_equal '2 + 2', record['expression']
      assert_equal 'r4/patient.json', record['input_fixture']
      assert_equal 'plain', record['model']
      assert_equal [4], record['expected']
      assert_equal '2.0.0', record['target']
      assert_equal 'case-two', record['origin']['case']
      assert_equal 'r4/fhirpath/tests.xml', record['origin']['path']
      assert_equal({ 'resourceType' => 'Patient' }, record['resource'])
    end
  end

  def test_importer_is_deterministic_and_retains_empty_expected_output
    Dir.mktmpdir('fhirpath-import') do |root|
      source = File.join(root, 'tests.xml')
      File.write(source, <<~XML)
        <tests reference="http://hl7.org/fhirpath|2.0.0">
          <group name="core">
            <test name="second"><expression>2 + 2</expression><output type="integer">4</output></test>
            <test name="first"><expression>{}</expression></test>
          </group>
        </tests>
      XML
      options = { source_root: root, suite_path: 'tests.xml', suite_commit: 'abc', case_ids: %w[first second] }

      first = FHIRPath::Conformance::Importer.new(**options).import
      second = FHIRPath::Conformance::Importer.new(**options).import

      assert_equal first, second
      assert_equal(%w[first second], first.map { |record| record['id'] })
      assert_equal [], first.first['expected']
    end
  end

  def test_expected_error_matches_before_unsupported_and_host_classification
    vectors = [
      {
        'id' => 'unsupported-error', 'expression' => 'anything', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::UnsupportedFeatureError', 'code' => 'unsupported_function' }
      },
      {
        'id' => 'host-error', 'expression' => 'anything', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::HostError', 'code' => 'host_error' }
      },
      {
        'id' => 'wrong-error', 'expression' => 'anything', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::UnsupportedFeatureError', 'code' => 'unsupported_function' }
      }
    ]
    error_types = [
      FHIRPath::UnsupportedFeatureError.new('unsupported', code: :unsupported_function),
      FHIRPath::HostError.new('host', code: :host_error),
      FHIRPath::HostError.new('wrong', code: :different_host_error)
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path, evaluator: ->(_vector) { raise error_types.shift })

      assert_equal(%w[pass pass defect], report[:cases].map { |result| result['classification'] })
      assert_equal 2, report[:counts]['pass']
      assert_equal 1, report[:counts]['defect']
      assert_equal 0, report[:counts]['unsupported']
      assert_equal 0, report[:counts]['host-dependent']
    end
  end

  def test_differential_report_contains_schema_fields_and_capability_totals
    Tempfile.create('fhirpath-vector') do |file|
      file.write({
        'id' => 'schema-001', 'suite' => 'manual', 'suite_commit' => 'abc',
        'expression' => '2 + 2', 'input_fixture' => nil, 'model' => 'plain',
        'target' => '2.0.0', 'capability' => 'arithmetic', 'expected' => [4], 'resource' => {}
      }.to_json)
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal(%w[suite suite_commit expression input_fixture model expected actual target classification],
                   %w[suite suite_commit expression input_fixture model expected actual target
                      classification].select do |key|
                     result.key?(key)
                   end)
      assert_equal [4], result['actual']
      assert_equal [], result['host_features']
      assert_equal 1, report[:capability_totals]['arithmetic'][:total]
      assert_equal 1, report[:capability_totals]['arithmetic'][:counts]['pass']
    end
  end

  def test_importer_maps_xml_to_matching_json_without_losing_types_and_records_host_features
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4', 'fhirpath'))
      FileUtils.mkdir_p(File.join(root, 'r4', 'examples'))
      File.write(File.join(root, 'r4', 'fhirpath', 'tests.xml'), <<~XML)
        <tests><group name="model"><test name="typed" inputfile="patient-example.xml">
          <expression>Patient.active</expression><output type="boolean">true</output>
        </test></group></tests>
      XML
      File.write(File.join(root, 'r4', 'patient-example.xml'), '<Patient xmlns="http://hl7.org/fhir"/>')
      expected_resource = {
        'resourceType' => 'Patient', 'active' => true,
        'name' => [{ 'given' => %w[Peter James] }, { 'given' => %w[Jim] }],
        'contact' => [{ 'name' => { 'family' => 'du Marché' } }]
      }
      File.write(File.join(root, 'r4', 'examples', 'patient-example.json'), expected_resource.to_json)

      record = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'r4/fhirpath/tests.xml', suite_commit: 'abc', fixture_root: 'r4',
        host_features: ['plain-json-fixture']
      ).import.first

      assert_equal expected_resource, record['resource']
      assert_equal 'r4/patient-example.xml', record['input_fixture']
      assert_equal 'r4/examples/patient-example.json', record['fixture_source']
      assert_equal ['plain-json-fixture'], record['host_features']
    end
  end

  def test_importer_retains_unconvertible_xml_as_an_auditable_not_run_record
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests><group name="model"><test name="xml-only" inputfile="complex.xml">
          <expression>Patient.name</expression><output type="string">Peter</output>
        </test></group></tests>
      XML
      File.write(
        File.join(root, 'complex.xml'),
        '<Patient xmlns="http://hl7.org/fhir"><active value="true"/></Patient>'
      )

      record = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc'
      ).import.first

      assert_equal 'complex.xml', record['input_fixture']
      assert_equal 'not-run', record['classification']
      assert_match(/matching JSON fixture/, record['not_run_reason'])
      assert_nil record['resource']
    end
  end

  def test_disabled_imported_case_is_retained_and_vector_runner_does_not_evaluate_it
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests><group name="disabled"><test name="disabled-case" disabled="true">
          <expression>1 + 1</expression><output type="integer">2</output>
        </test></group></tests>
      XML
      record = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc'
      ).import.first
      assert_equal 'not-run', record['classification']
      assert_match(/disabled/, record['not_run_reason'])

      calls = 0
      result = FHIRPath::VectorRunner.execute(
        record,
        1,
        evaluator: lambda do |_vector|
          calls += 1
          [2]
        end
      )
      assert_equal 0, calls
      assert_equal 'not-run', result['classification']
      assert_nil result['actual']
    end
  end

  def test_yaml_import_normalizes_real_fhirpath_py_shape_into_independent_records
    Dir.mktmpdir('fhirpath-yaml') do |root|
      FileUtils.mkdir_p(File.join(root, 'tests', 'cases'))
      File.write(File.join(root, 'tests', 'cases', 'sample.yaml'), <<~YAML)
        tests:
          - expression:
              - Patient.name.family
              - name.family
            result: [Chalmers]
          - 'group: Disabled cases':
              - desc: skipped
                expression: Patient.id
                disable: true
                result: [example]
        subject:
          resourceType: Patient
          name:
            - family: Chalmers
      YAML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests/cases/sample.yaml', suite: 'fhirpath-py',
        suite_commit: '19f631684cf413836284faed68ee3f4e4d0192ef', host_features: []
      ).import

      assert_equal 3, records.length
      assert_equal(['Patient.name.family', 'name.family', 'Patient.id'], records.map { |r| r['expression'] })
      assert_equal([['Chalmers'], ['Chalmers'], ['example']], records.map { |r| r['expected'] })
      assert_equal(%w[fhirpath-py fhirpath-py fhirpath-py], records.map { |r| r['suite'] })
      assert_equal([nil, nil, 'not-run'], records.map { |r| r['classification'] })
      records[0]['resource']['name'][0]['family'] = 'changed'
      assert_equal 'Chalmers', records[1]['resource']['name'][0]['family']
    end
  end

  def test_unrelated_standard_error_is_a_defect_even_when_error_is_expected
    Tempfile.create('fhirpath-vector') do |file|
      file.write({ id: 'standard-error', expression: 'anything', resource: {},
                   error: true }.to_json)
      file.write("\n")
      file.flush

      result = FHIRPath::VectorRunner.run(
        file.path, evaluator: ->(_vector) { raise StandardError, 'boom' }
      )[:cases].first

      assert_equal 'defect', result['classification']
      assert_equal 'StandardError', result['actual_error']['class']
    end
  end

  def test_runtime_pipeline_has_no_python_invocation
    runtime = Dir[File.expand_path('../{lib,script}/**/*.rb', __dir__)].map { |path| File.read(path) }.join("\n")

    refute_match(/(?:system|exec|spawn|Open3).*python/i, runtime)
  end
end
