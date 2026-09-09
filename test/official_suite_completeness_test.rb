# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'rexml/document'
require 'tmpdir'
require 'fileutils'

# Separate require so the script's `if __FILE__==$0` guard keeps it loadable.
require_relative '../script/check_official_suite_completeness'

class FHIRPathOfficialSuiteCompletenessTest < Minitest::Test
  def with_corpus
    Dir.mktmpdir('fhirpath-official') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4', 'fhirpath'))
      File.write(File.join(root, 'r4', 'fhirpath', 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="case-one"><expression>1 + 1</expression><output type="integer">2</output></test>
            <test name="case-two"><expression>2 + 2</expression><output type="integer">4</output></test>
            <test name="case-three"><expression>3 + 3</expression><output type="integer">6</output></test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'exclusions.json'), '{ "entries": [] }')

      yield root
    end
  end

  def test_complete_corpus_passes
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"}}
        {"id":"case-two","origin":{"case":"case-two"}}
        {"id":"case-three","origin":{"case":"case-three"}}
      JSONL

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl)
      assert_equal 'pass', report[:status], report[:errors].inspect
      assert_equal 3, report[:summary][:source_cases]
      assert_equal 3, report[:summary][:corpus_records]
    end
  end

  def test_silent_loss_is_rejected
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"}}
        {"id":"case-two","origin":{"case":"case-two"}}
      JSONL

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl)
      refute report[:valid]
      assert_match(/source has 3 cases but corpus has 2/, report[:errors].join("\n"))
    end
  end

  def test_surprise_extra_record_is_rejected
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"}}
        {"id":"case-two","origin":{"case":"case-two"}}
        {"id":"case-three","origin":{"case":"case-three"}}
        {"id":"case-extra","origin":{"case":"case-extra"}}
      JSONL

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl)
      refute report[:valid]
      assert_match(/case-extra.*unexpected case/, report[:errors].join("\n"))
    end
  end

  def test_excluded_case_import_is_rejected
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"}}
        {"id":"case-two","origin":{"case":"case-two"}}
        {"id":"case-three","origin":{"case":"case-three"}}
      JSONL
      exclusions = { 'entries' => [{ 'case' => 'case-two', 'category' => 'test', 'reason' => 'intentional' }] }
      exclusions_path = File.join(root, 'exclusions.json')
      File.write(exclusions_path, JSON.generate(exclusions))

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/case-two.*excluded case must not appear/, report[:errors].join("\n"))
    end
  end

  def test_stale_exclusion_is_rejected
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"}}
        {"id":"case-two","origin":{"case":"case-two"}}
        {"id":"case-three","origin":{"case":"case-three"}}
      JSONL
      exclusions = { 'entries' => [{ 'case' => 'case-gone', 'category' => 'test', 'reason' => 'removed' }] }
      exclusions_path = File.join(root, 'exclusions.json')
      File.write(exclusions_path, JSON.generate(exclusions))

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl, exclusions_path)
      refute report[:valid]
      assert_match(/stale exclusion.*case-gone/, report[:errors].join("\n"))
    end
  end

  def test_not_run_without_reason_is_rejected
    with_corpus do |root|
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"case-one","origin":{"case":"case-one"},"classification":"not-run"}
        {"id":"case-two","origin":{"case":"case-two"}}
        {"id":"case-three","origin":{"case":"case-three"}}
      JSONL

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl)
      refute report[:valid]
      assert_match(/not-run without a reason/, report[:errors].join("\n"))
    end
  end

  def test_duplicate_case_names_are_handled_correctly
    Dir.mktmpdir('fhirpath-official-dup') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4', 'fhirpath'))
      File.write(File.join(root, 'r4', 'fhirpath', 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="dup"><expression>1 + 1</expression><output type="integer">2</output></test>
            <test name="dup"><expression>2 + 2</expression><output type="integer">4</output></test>
            <test name="other"><expression>3 + 3</expression><output type="integer">6</output></test>
          </group>
        </tests>
      XML

      # The importer disambiguates duplicates to "dup" and "dup~2".
      # The completeness checker counts raw <test> elements, so source=3, corpus must=3.
      jsonl = File.join(root, 'out.jsonl')
      File.write(jsonl, <<~JSONL)
        {"id":"dup","origin":{"case":"dup"}}
        {"id":"dup~2","origin":{"case":"dup"}}
        {"id":"other","origin":{"case":"other"}}
      JSONL

      report = run_check(File.join(root, 'r4', 'fhirpath', 'tests.xml'), jsonl)
      assert_equal 'pass', report[:status], report[:errors].inspect
      assert_equal 3, report[:summary][:source_cases]
    end
  end

  private

  def run_check(suite_xml, jsonl_path, exclusions_path = nil)
    OfficialSuiteCompleteness.run_check(suite_xml, jsonl_path, exclusions_path)
  end
end
