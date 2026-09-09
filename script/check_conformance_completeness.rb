#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/conformance/importer'

# Verify that a fhirpath.js compatibility corpus is complete: every source case
# in an adopted file is imported exactly once (executable, unsupported, or
# not-run with a reason) and every excluded file / case has a matching entry in
# the exclusion ledger. Rejects silent loss, surprise extra records, and stale
# exclusions.
#
# Usage:
#   check_conformance_completeness.rb MANIFEST JSONL [EXCLUSIONS]
#
#   MANIFEST     conformance/fhirpath-js/manifest.json
#   JSONL        one JSON record per line produced by import_vectors.rb
#   EXCLUSIONS   conformance/exclusions/fhirpath-js.json (optional)
#
# Exits non-zero (reporting `status: fail`) on any incompleteness.

# Detect the group key in a YAML entry.
def detect_group_key(entry)
  entry.keys.find { |key| key.to_s.start_with?('group') }
end

# Extract the group name from a group key.
def group_name_from(key)
  key.to_s.delete_prefix('group:').strip
end

# Collect leaf expressions from a YAML entry.
def collect_leaf_cases(entry, group, cases)
  return unless entry.key?('expression')

  expressions = entry['expression'].is_a?(Array) ? entry['expression'] : [entry['expression']]
  expressions.each do |expression|
    cases << { 'group' => group, 'expression' => expression.to_s, 'desc' => entry['desc']&.to_s }
  end
end

# Walk nested YAML test groups and collect every leaf expression.
def flatten_source_cases(value, group = nil, cases = [])
  Array(value).each do |entry|
    next unless entry.is_a?(Hash)

    group_key = detect_group_key(entry)
    if group_key
      flatten_source_cases(entry.fetch(group_key), group_name_from(group_key), cases)
    else
      collect_leaf_cases(entry, group, cases)
    end
  end
  cases
end

# Count expression-level test cases in a source YAML file.
def count_source_cases(source_root, file_path)
  path = File.join(source_root, file_path)
  raise "missing vendor source: #{path}" unless File.file?(path)

  document = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
  flatten_source_cases(document.fetch('tests'))
end

# Filter records by their origin path.
def imported_by_path(records, source_path)
  records.select { |record| record.dig('origin', 'path') == source_path }
end

# Build an exclusion lookup keyed by [path, case_or_expression].
def exclude_lookup(exclusions)
  exclusions['entries'].each_with_object({}) do |entry, lookup|
    key = [entry['path'], entry['case'] || entry['expression']]
    lookup[key] = entry
  end
end

# Check a single adopted file for case completeness.
def check_adopted_file(records, source_root, file)
  path = file['path']
  source_cases = count_source_cases(source_root, path)
  imported = imported_by_path(records, path)
  errors = []

  if source_cases.length != imported.length
    errors << "#{path}: source has #{source_cases.length} cases but imported #{imported.length} records"
  end

  source_exprs = source_cases.map { |c| c['expression'] }.sort
  imported_exprs = imported.map { |r| r['expression'] }.sort
  return errors if source_exprs == imported_exprs

  missing = source_exprs - imported_exprs
  extra = imported_exprs - source_exprs
  errors << "#{path}: expression mismatch (missing=#{missing.uniq.length} extra=#{extra.uniq.length})" if missing.any?
  errors << "#{path}: expression mismatch (extra) #{extra.uniq.inspect}" if extra.any?
  errors
end

# Check that excluded files have ledger entries and no imported records.
def check_excluded_file(records, lookup, file)
  path = file['path']
  errors = []

  excluded_records = imported_by_path(records, path)
  unless excluded_records.empty?
    errors << "#{path}: excluded file must not be imported (#{excluded_records.length} records found)"
  end
  has_ledger_entry = lookup.key?([path, nil]) || lookup.key?([path, ''])
  errors << "#{path}: excluded file lacks an exclusion-ledger entry" unless has_ledger_entry
  errors
end

# Check that not-run records carry a reason.
def check_not_run_reasons(records)
  records.select { |r| r['classification'] == 'not-run' && r['not_run_reason'].to_s.empty? }.map do |record|
    "record #{record['id']}: not-run without a reason"
  end
end

# Check whether an exclusion expression still exists in the source.
def expression_still_exists?(source_cases, expression)
  source_cases.any? { |c| c['expression'] == expression }
end

# Check for stale exclusions referencing absent paths or expressions.
def check_stale_exclusions(manifest, exclusions, source_root)
  manifest_paths = manifest['files'].filter_map { |f| f['path'] }.to_set
  errors = []

  exclusions['entries'].each do |entry|
    path = entry['path']
    unless manifest_paths.include?(path)
      errors << "stale exclusion: #{path} is not in the manifest"
      next
    end
    file_entry = manifest['files'].find { |f| f['path'] == path }
    next unless file_entry && file_entry['status'] == 'adopted' && entry['expression']

    source_cases = count_source_cases(source_root, path)
    exists = expression_still_exists?(source_cases, entry['expression'])
    errors << "stale exclusion: #{path} no longer has expression #{entry['expression'].inspect}" unless exists
  end
  errors
end

def run_check(manifest_path, jsonl_path, exclusions_path)
  manifest = JSON.parse(File.read(manifest_path))
  source_root = File.dirname(manifest_path)
  records = File.foreach(jsonl_path).each_with_object([]) do |line, acc|
    next if line.strip.empty?

    acc << JSON.parse(line)
  end
  exclusions = exclusions_path ? JSON.parse(File.read(exclusions_path)) : { 'entries' => [] }
  lookup = exclude_lookup(exclusions)

  errors = []
  summary = { total_files: 0, adopted_files: 0, source_cases: 0, imported_records: 0, excluded_files: 0 }

  adopted = manifest['files'].select { |f| f['status'] == 'adopted' }
  adopted.each do |file|
    summary[:total_files] += 1
    summary[:adopted_files] += 1
    source_cases = count_source_cases(source_root, file['path'])
    imported = imported_by_path(records, file['path'])
    summary[:source_cases] += source_cases.length
    summary[:imported_records] += imported.length
    errors.concat(check_adopted_file(records, source_root, file))
  end

  excluded = manifest['files'].select { |f| f['status'] == 'excluded' }
  excluded.each do |file|
    summary[:total_files] += 1
    summary[:excluded_files] += 1
    errors.concat(check_excluded_file(records, lookup, file))
  end

  errors.concat(check_not_run_reasons(records))
  errors.concat(check_stale_exclusions(manifest, exclusions, source_root))

  {
    status: errors.empty? ? 'pass' : 'fail',
    valid: errors.empty?,
    errors: errors,
    summary: summary,
    exclusions: exclusions['entries'].length
  }
end

if $PROGRAM_NAME == __FILE__
  manifest = ARGV.fetch(0) { abort "usage: #{File.basename($PROGRAM_NAME)} MANIFEST JSONL [EXCLUSIONS]" }
  jsonl = ARGV.fetch(1)
  exclusions = ARGV[2]
  report = run_check(manifest, jsonl, exclusions)
  puts JSON.pretty_generate(report)
  exit(report[:valid] ? 0 : 1)
end
