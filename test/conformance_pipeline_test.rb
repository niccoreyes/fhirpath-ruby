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
      # A structurally unsupported fixture (an integer element with a
      # non-integer value) must fail closed rather than emit a wrong-typed
      # resource.
      File.write(
        File.join(root, 'complex.xml'),
        '<Patient xmlns="http://hl7.org/fhir"><telecom><rank value="abc"/></telecom></Patient>'
      )

      record = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc'
      ).import.first

      assert_equal 'complex.xml', record['input_fixture']
      assert_equal 'not-run', record['classification']
      assert_match(/unsupported XML structure/, record['not_run_reason'])
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

  def test_importer_disambiguates_duplicate_case_names_with_unique_ids
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests><group name="core">
          <test name="dup"><expression>1 | 2</expression></test>
          <test name="other"><expression>3 | 4</expression></test>
          <test name="dup"><expression>1 | 3</expression></test>
        </group></tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'ebb15f74f95a4731e59099c4244eeed734c9e447'
      ).import

      assert_equal(%w[dup dup~2 other], records.map { |r| r['id'] })
      assert_equal(%w[dup dup other], records.map { |r| r['origin']['case'] })
      report = FHIRPath::Conformance::CorpusValidator.validate(records)
      assert report[:valid], report[:errors].inspect
    end
  end

  def test_load_full_suite_imports_all_xml_cases_without_case_ids_filter
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4', 'fhirpath'))
      File.write(File.join(root, 'r4', 'fhirpath', 'tests.xml'), <<~XML)
        <tests><group name="core">
          <test name="case-one"><expression>1 + 1</expression><output type="integer">2</output></test>
          <test name="case-two"><expression>2 + 2</expression><output type="integer">4</output></test>
          <test name="case-three"><expression>3 + 3</expression><output type="integer">6</output></test>
        </group></tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'r4/fhirpath/tests.xml', suite_commit: 'abc',
        load_full_suite: true
      ).import

      assert_equal 3, records.length
      assert_equal(%w[case-one case-three case-two], records.map { |r| r['id'] })
      assert_equal([2, 6, 4], records.map { |r| r['expected'].first })
    end
  end
end

class FHIRPathCorpusValidatorTest < Minitest::Test
  def immutable_sha
    'ebb15f74f95a4731e59099c4244eeed734c9e447'
  end

  def make_records(count = 3)
    (1..count).map do |i|
      {
        'id' => "case-#{i}".rjust(4, '0'), 'suite' => 'FHIR/fhir-test-cases',
        'suite_commit' => immutable_sha, 'expression' => "#{i} + #{i}",
        'input_fixture' => nil, 'model' => 'plain', 'host_features' => [],
        'target' => '2.0.0', 'capability' => 'testBasics', 'expected' => [i * 2],
        'resource' => {}, 'variables' => {},
        'origin' => { 'suite' => 'FHIR/fhir-test-cases', 'suite_commit' => immutable_sha,
                      'case' => "case-#{i}", 'path' => 'r4/fhirpath/tests.xml' }
      }
    end
  end

  def test_corpus_validator_accepts_wellformed_records
    report = FHIRPath::Conformance::CorpusValidator.validate(make_records)

    assert report[:valid], report[:errors].inspect
    assert_equal 3, report[:total]
    assert_equal 'pass', report[:status]
  end

  def test_corpus_validator_rejects_duplicate_ids
    records = make_records(2)
    records[1]['id'] = records[0]['id']

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/duplicate id/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_rejects_missing_suite_commit
    records = make_records(1)
    records[0].delete('suite_commit')
    records[0]['origin'].delete('suite_commit')

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/suite_commit/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_rejects_mutable_or_empty_suite_commit
    ['master', 'main', 'HEAD', '1.7.69', 'v1.2.3', ''].each do |bad|
      records = make_records(1)
      records[0]['suite_commit'] = bad

      report = FHIRPath::Conformance::CorpusValidator.validate(records)

      refute report[:valid], "expected #{bad.inspect} to be rejected"
      assert_match(/immutable SHA/i, report[:errors].join("\n"))
    end
  end

  def test_corpus_validator_rejects_invalid_classification
    records = make_records(1)
    records[0]['classification'] = 'bogus'

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/classification/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_requires_not_run_reason_when_not_run
    records = make_records(1)
    records[0]['classification'] = 'not-run'

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/not_run_reason/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_rejects_unsupported_model
    records = make_records(1)
    records[0]['model'] = 'patient'

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/model/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_rejects_source_path_escape
    records = make_records(1)
    records[0]['origin']['path'] = '../outside.xml'

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/escape/i, report[:errors].join("\n"))
  end

  def test_corpus_validator_rejects_unstable_ordering
    records = make_records(3).reverse

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    refute report[:valid]
    assert_match(/order/i, report[:errors].join("\n"))
  end

  def test_two_imports_produce_identical_digest
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests><group name="core">
          <test name="second"><expression>2 + 2</expression><output type="integer">4</output></test>
          <test name="first"><expression>{}</expression></test>
        </group></tests>
      XML
      options = { source_root: root, suite_path: 'tests.xml', suite_commit: immutable_sha }
      first = FHIRPath::Conformance::Importer.new(**options).import
      second = FHIRPath::Conformance::Importer.new(**options).import

      assert_equal first, second
      assert_equal FHIRPath::Conformance::CorpusValidator.validate(first)[:digest],
                   FHIRPath::Conformance::CorpusValidator.validate(second)[:digest]
    end
  end

  def test_corpus_validator_produces_baseline_metadata
    records = make_records(3)

    report = FHIRPath::Conformance::CorpusValidator.validate(records)

    assert_equal 3, report[:total]
    assert_equal 3, report[:record_counts]['evaluable']
    assert_equal immutable_sha, report[:source_sha]
    assert_match(/\Asha256:[0-9a-f]{64}\z/, report[:digest])
    assert_equal 3, report[:capability_totals]['testBasics'][:total]
    assert_equal 3, report[:capability_totals]['testBasics'][:counts]['evaluable']
  end
end
