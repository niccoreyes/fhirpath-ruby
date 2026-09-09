#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'rexml/document'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# Verify that the official HL7 FHIRPath XML suite is complete: every source case
# in the XML suite appears exactly once in the corpus (as executable, unsupported,
# host-dependent, excluded, or not-run) and every excluded case has a matching
# entry in the exclusion ledger. Rejects silent loss, surprise extra records, and
# stale exclusions.
#
# Usage:
#   check_official_suite_completeness.rb SUITE_XML CORPUS_JSONL [EXCLUSIONS]
#
#   SUITE_XML     conformance/r4/fhirpath/tests-fhir-r4.xml
#   CORPUS_JSONL  one JSON record per line produced by the importer
#   EXCLUSIONS    conformance/exclusions/official-r4.json (optional)
#
# Exits non-zero (reporting `status: fail`) on any incompleteness.

# Namespace to avoid function name collisions with check_conformance_completeness.rb.
module OfficialSuiteCompleteness
  # Count test cases and return both the count and the sorted list of case names.
  def self.count_source_cases(suite_xml)
    raise "missing suite XML: #{suite_xml}" unless File.file?(suite_xml)

    document = REXML::Document.new(File.read(suite_xml))
    tests = document.root.elements.to_a('group/test')
    case_names = tests.map { |test| test.attributes['name'].to_s }.sort
    [tests.length, case_names]
  end

  # Load corpus records from a JSONL file.
  def self.load_corpus_records(jsonl_path)
    raise "missing corpus: #{jsonl_path}" unless File.file?(jsonl_path)

    records = []
    File.foreach(jsonl_path) do |line|
      next if line.strip.empty?

      records << JSON.parse(line)
    end
    records
  end

  # Build a lookup of source case names from the corpus, keyed by origin.case.
  def self.case_lookup(records)
    records.each_with_object({}) do |record, lookup|
      next unless record.is_a?(Hash)

      case_name = record.dig('origin', 'case')
      next unless case_name

      lookup[case_name] ||= []
      lookup[case_name] << record['id']
    end
  end

  # Build an exclusion lookup keyed by case name.
  def self.exclude_lookup(exclusions)
    exclusions['entries'].each_with_object({}) do |entry, lookup|
      key = entry['case'] || entry['path']
      lookup[key] = entry
    end
  end

  # Check that every source case appears exactly once in the corpus.
  def self.check_case_coverage(source_cases, corpus_cases, errors)
    source_set = source_cases.to_set
    corpus_set = corpus_cases.keys.to_set

    missing = source_set - corpus_set
    extra = corpus_set - source_set

    missing.each do |case_name|
      errors << "#{case_name}: source case not found in corpus"
    end
    extra.each do |case_name|
      errors << "#{case_name}: corpus has unexpected case not in source"
    end
  end

  # Check that excluded cases have ledger entries and no corpus records.
  def self.check_exclusions(source_cases, corpus_cases, lookup, errors)
    source_cases.each do |case_name|
      next unless lookup.key?(case_name)

      excluded_records = corpus_cases[case_name]
      unless excluded_records.empty?
        errors << "#{case_name}: excluded case must not appear in corpus (#{excluded_records.length} records found)"
      end
    end
  end

  # Check for stale exclusions referencing absent source cases.
  def self.check_stale_exclusions(lookup, source_cases, errors)
    source_set = source_cases.to_set
    lookup.each_key do |case_name|
      next if source_set.include?(case_name)

      errors << "stale exclusion: #{case_name} is not a source case"
    end
  end

  # Check that not-run records carry a reason.
  def self.check_not_run_reasons(records, errors)
    records.each do |record|
      next unless record.is_a?(Hash)
      next unless record['classification'] == 'not-run'
      next unless record['not_run_reason'].to_s.empty?

      errors << "record #{record['id']}: not-run without a reason"
    end
  end

  def self.run_check(suite_xml, jsonl_path, exclusions_path = nil)
    source_count, source_cases = count_source_cases(suite_xml)
    records = load_corpus_records(jsonl_path)
    corpus_cases = case_lookup(records)
    exclusions = exclusions_path ? JSON.parse(File.read(exclusions_path)) : { 'entries' => [] }
    lookup = exclude_lookup(exclusions)

    errors = []

    # Source count must equal corpus count.
    if source_count != records.length
      errors << "source has #{source_count} cases but corpus has #{records.length} records"
    end

    # Every source case must appear in the corpus.
    check_case_coverage(source_cases, corpus_cases, errors)

    # Excluded cases must not appear in the corpus.
    check_exclusions(source_cases, corpus_cases, lookup, errors)

    # Stale exclusions are rejected.
    check_stale_exclusions(lookup, source_cases, errors)

    # Not-run records must have a reason.
    check_not_run_reasons(records, errors)

    {
      status: errors.empty? ? 'pass' : 'fail',
      valid: errors.empty?,
      errors: errors,
      summary: {
        source_cases: source_count,
        corpus_records: records.length,
        exclusions: exclusions['entries'].length
      }
    }
  end
end

if $PROGRAM_NAME == __FILE__
  suite_xml = ARGV.fetch(0) { abort "usage: #{File.basename($PROGRAM_NAME)} SUITE_XML CORPUS_JSONL [EXCLUSIONS]" }
  jsonl = ARGV.fetch(1)
  exclusions = ARGV[2]
  report = OfficialSuiteCompleteness.run_check(suite_xml, jsonl, exclusions)
  puts JSON.pretty_generate(report)
  exit(report[:valid] ? 0 : 1)
end
