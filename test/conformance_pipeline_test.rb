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
      assert_equal 1, report[:capability_totals]['arithmetic'][:total]
      assert_equal 1, report[:capability_totals]['arithmetic'][:counts]['pass']
    end
  end

  def test_runtime_pipeline_has_no_python_invocation
    runtime = Dir[File.expand_path('../{lib,script}/**/*.rb', __dir__)].map { |path| File.read(path) }.join("\n")

    refute_match(/(?:system|exec|spawn|Open3).*python/i, runtime)
  end
end
