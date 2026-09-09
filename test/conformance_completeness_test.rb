# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'digest'
require 'tmpdir'
require 'fileutils'

# Separate require so the script's `if __FILE__==$0` guard keeps it loadable.
require_relative '../script/check_conformance_completeness'

class FHIRPathConformanceCompletenessTest < Minitest::Test
  JS_COMMIT = '8a4f5deac10bf3b491da139faaa05ef851ecc681'

  def with_corpus
    Dir.mktmpdir('fhirpath-js') do |root|
      FileUtils.mkdir_p(File.join(root, 'cases'))
      File.write(File.join(root, 'cases', 'adopted.yaml'), <<~YAML)
        tests:
          - 'group: A':
            - expression: Resource.id
              result: ['example']
            - expression: Observation.value
              result: ['high']
      YAML
      File.write(File.join(root, 'cases', 'excluded.yaml'), <<~YAML)
        tests:
          - 'group: X':
            - expression: something.getValue()
              result: ['x']
      YAML

      manifest = {
        'schema' => 'fhirpath-conformance-v1',
        'suite' => 'HL7/fhirpath.js',
        'suite_commit' => JS_COMMIT,
        'target' => '2.0.0',
        'model' => 'r4',
        'source' => 'cases/adopted.yaml',
        'load_full_suite' => false,
        'files' => [
          { 'path' => 'cases/adopted.yaml', 'sha256' => 'a', 'status' => 'adopted' },
          { 'path' => 'cases/excluded.yaml', 'sha256' => 'b', 'status' => 'excluded',
            'reason' => 'implementation-specific' }
        ]
      }
      manifest_path = File.join(root, 'manifest.json')
      File.write(manifest_path, JSON.generate(manifest))

      exclusions = {
        'entries' => [
          { 'path' => 'cases/excluded.yaml', 'category' => 'implementation-specific',
            'reason' => 'implementation-specific' },
          { 'path' => 'cases/adopted.yaml', 'expression' => 'Resource.id',
            'category' => 'model-release', 'reason' => 'r4 model gap' }
        ]
      }
      exclusions_path = File.join(root, 'exclusions.json')
      File.write(exclusions_path, JSON.generate(exclusions))

      yield root, manifest_path, exclusions_path
    end
  end

  def test_complete_import_passes
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, lines(
                          record('cases/adopted.yaml', 'Resource.id', 'r4'),
                          record('cases/adopted.yaml', 'Observation.value', 'r4')
                        ))

      report = run_check(manifest_path, jsonl, exclusions_path)
      assert_equal 'pass', report[:status], report[:errors].inspect
      assert_equal 2, report[:summary][:source_cases]
      assert_equal 2, report[:summary][:imported_records]
    end
  end

  def test_silent_loss_is_rejected
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, lines(record('cases/adopted.yaml', 'Resource.id', 'r4')))

      report = run_check(manifest_path, jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/source has 2 cases but imported 1/, report[:errors].join("\n"))
    end
  end

  def test_surprise_extra_record_is_rejected
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, lines(
                          record('cases/adopted.yaml', 'Resource.id', 'r4'),
                          record('cases/adopted.yaml', 'Observation.value', 'r4'),
                          record('cases/adopted.yaml', 'Resource.id', 'r4')
                        ))

      report = run_check(manifest_path, jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/source has 2 cases but imported 3/, report[:errors].join("\n"))
    end
  end

  def test_excluded_file_import_is_rejected
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, lines(
                          record('cases/adopted.yaml', 'Resource.id', 'r4'),
                          record('cases/adopted.yaml', 'Observation.value', 'r4'),
                          record('cases/excluded.yaml', 'something.getValue()', 'r4')
                        ))

      report = run_check(manifest_path, jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/excluded file must not be imported/, report[:errors].join("\n"))
    end
  end

  def test_stale_exclusion_is_rejected
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, lines(
                          record('cases/adopted.yaml', 'Resource.id', 'r4'),
                          record('cases/adopted.yaml', 'Observation.value', 'r4')
                        ))
      # Add a stale per-case exclusion for an expression that no longer exists.
      extra = { 'path' => 'cases/adopted.yaml', 'expression' => 'Gone.gone',
                'category' => 'model-release', 'reason' => 'stale' }
      exclusions = JSON.parse(File.read(exclusions_path))
      exclusions['entries'] << extra
      File.write(exclusions_path, JSON.generate(exclusions))

      report = run_check(manifest_path, jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/stale exclusion/, report[:errors].join("\n"))
    end
  end

  def test_not_run_without_reason_is_rejected
    with_corpus do |root, manifest_path, exclusions_path|
      jsonl = File.join(root, 'out.jsonl')
      baseline = record('cases/adopted.yaml', 'Resource.id', 'r4')
      baseline['classification'] = 'not-run' # missing not_run_reason
      File.write(jsonl, lines(
                          baseline,
                          record('cases/adopted.yaml', 'Observation.value', 'r4')
                        ))

      report = run_check(manifest_path, jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/not-run without a reason/, report[:errors].join("\n"))
    end
  end

  private

  def record(path, expression, model)
    {
      'id' => "#{path}:0-#{Digest::SHA256.hexdigest(expression)[0, 7]}",
      'suite' => 'HL7/fhirpath.js', 'suite_commit' => JS_COMMIT,
      'expression' => expression, 'model' => model, 'target' => '2.0.0',
      'capability' => 'A', 'expected' => [], 'resource' => {}, 'variables' => {},
      'origin' => { 'suite' => 'HL7/fhirpath.js', 'suite_commit' => JS_COMMIT,
                    'path' => path, 'source' => 'fhirpath.js' }
    }
  end

  def lines(*records)
    "#{records.map { |r| JSON.generate(r) }.join("\n")}\n"
  end
end
