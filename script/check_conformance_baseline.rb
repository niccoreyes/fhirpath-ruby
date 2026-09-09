#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

# Check a conformance baseline report against a checked-in baseline file.
# Exits non-zero on unexpected regressions; exits zero on acceptable diffs.
#
# Usage:
#   check_conformance_baseline.rb --current CURRENT_JSON [--baseline BASELINE_JSON] [--strict]
#
# Flags:
#   --baseline PATH  Path to the checked-in baseline JSON (optional when --strict).
#   --strict         Fail on any deviation from baseline, including improvements.
#
# Comparison rules:
#   - Total case count must match source counts; drift is a regression.
#   - Pass count may increase (improvement) or stay equal; cannot decrease.
#   - Defect count may not increase; a decrease is an improvement.
#   - not-run count may decrease (improvement) or stay equal; cannot increase.
#   - Unsupported/host-dependent counts are informational and do not gate.

def fail(message)
  warn "FAIL: #{message}"
  exit 1
end

def log_warn(message)
  warn "WARN: #{message}"
end

def usage
  "usage: #{$PROGRAM_NAME} --current PATH [--baseline PATH] [--strict]"
end

# Parse args
current_path = nil
baseline_path = nil
strict_mode = false
i = 0
while i < ARGV.length
  case ARGV[i]
  when '--current'
    current_path = ARGV[i + 1]
    i += 2
  when '--baseline'
    baseline_path = ARGV[i + 1]
    i += 2
  when '--strict'
    strict_mode = true
    i += 1
  else
    i += 1
  end
end

fail usage unless current_path && File.exist?(current_path)
fail usage unless baseline_path.nil? || File.exist?(baseline_path)

current = JSON.parse(File.read(current_path))
baseline = baseline_path && JSON.parse(File.read(baseline_path))

required_keys = %w[schema_version corpus suite suite_commit target model
                   total record_counts classification_counts capability_totals
                   source_sha corpus_digest]
missing = required_keys.reject { |k| current.key?(k) }
fail "current report missing keys: #{missing.join(', ')}" if missing.any?

if baseline
  baseline_missing = required_keys.reject { |k| baseline.key?(k) }
  fail "baseline missing keys: #{baseline_missing.join(', ')}" if baseline_missing.any?
end

if baseline && current['schema_version'] != baseline['schema_version']
  fail "schema_version mismatch: #{current['schema_version']} vs #{baseline['schema_version']}"
end

if baseline && current['corpus'] != baseline['corpus']
  fail "corpus mismatch: #{current['corpus']} vs #{baseline['corpus']}"
end

if baseline && current['source_sha'] != baseline['source_sha']
  fail "source SHA drift: #{current['source_sha']} vs #{baseline['source_sha']}"
end

def count_value(counts, key)
  counts.is_a?(Hash) ? counts[key] || 0 : 0
end

current_counts = current['record_counts'] || {}
baseline_counts = baseline ? baseline['record_counts'] || {} : nil

if baseline && current['total'] != baseline['total']
  fail "total case count changed: #{baseline['total']} -> #{current['total']}"
end

current_pass = count_value(current_counts, 'pass')
baseline_pass = baseline ? count_value(baseline_counts, 'pass') : 0
fail "pass count decreased: #{baseline_pass} -> #{current_pass}" if baseline && current_pass < baseline_pass

current_defect = count_value(current_counts, 'defect')
baseline_defect = baseline ? count_value(baseline_counts, 'defect') : 0
fail "defect count increased: #{baseline_defect} -> #{current_defect}" if baseline && current_defect > baseline_defect

current_not_run = count_value(current_counts, 'not-run')
baseline_not_run = baseline ? count_value(baseline_counts, 'not-run') : 0
if baseline && current_not_run > baseline_not_run
  fail "not-run count increased: #{baseline_not_run} -> #{current_not_run}"
end

if strict_mode && baseline
  fail('strict mode: corpus digest changed') if current['corpus_digest'] != baseline['corpus_digest']

  %w[pass defect not-run unsupported host-dependent evaluable].each do |key|
    curr = count_value(current_counts, key)
    base = count_value(baseline_counts, key)
    fail "strict mode: #{key} changed from #{base} to #{curr}" if curr != base
  end
end

improvements = []
improvements << "pass: +#{current_pass - baseline_pass}" if baseline && current_pass > baseline_pass
improvements << "defect: #{baseline_defect} -> #{current_defect}" if baseline && current_defect < baseline_defect
improvements << "not-run: #{baseline_not_run} -> #{current_not_run}" if baseline && current_not_run < baseline_not_run

if baseline
  if improvements.empty?
    $stdout.puts 'baseline-match: no deviation from checked-in baseline'
  else
    $stdout.puts "baseline-improved: #{improvements.join(', ')}"
  end
else
  $stdout.puts "no-baseline: first run for corpus #{current['corpus']} (use --output-baseline to create one)"
end

$stdout.puts JSON.pretty_generate({
                                    'status' => 'pass',
                                    'current' => { 'total' => current['total'], 'record_counts' => current_counts },
                                    'baseline' => if baseline
                                                    { 'total' => baseline['total'],
                                                      'record_counts' => baseline_counts }
                                                  end,
                                    'improvements' => improvements
                                  })

exit 0
