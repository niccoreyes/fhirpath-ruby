#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/version'
require 'fhirpath/capability'

version = ARGV.fetch(0) { FHIRPath::VERSION }
version = version.sub(/\Av/, '')
report_path = ARGV[1]

rows = File.foreach(File.expand_path('../docs/feature-matrix.md', __dir__)).filter_map do |line|
  match = line.match(/^\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$/)
  next unless match && match[1] != 'Area' && !match[1].start_with?('--')

  { area: match[1], status: match[2], evidence: match[3] }
end

supported = rows.select { |row| row[:status] == 'Supported' }
unsupported = rows.select { |row| %w[Deferred].include?(row[:status]) || row[:status] == 'Not supported by design' }
host_dependent = rows.select { |row| row[:status] == 'Host-dependent' }

puts <<~NOTES
  # FHIRPath #{version}

  ## Release status

  - Release channel: #{FHIRPath::RELEASE_CHANNEL}
  - Normative FHIRPath target: #{FHIRPath::Capability.current.fhirpath}
  - Capability set: #{FHIRPath::Capability.current.capability_set.join(', ')}
  - Supported Ruby CI matrix: Ruby 3.2 and Ruby 3.3
  - License: MIT

  ## Supported behavior
  #{supported.map { |row| "- #{row[:area]} — #{row[:evidence]}" }.join("\n")}

  ## Explicitly unsupported or deferred behavior
  #{unsupported.map { |row| "- #{row[:area]} — #{row[:evidence]}" }.join("\n")}

  ## Host-dependent behavior
  #{host_dependent.map { |row| "- #{row[:area]} — #{row[:evidence]}" }.join("\n")}
NOTES

if report_path
  report = JSON.parse(File.read(report_path))
  counts = report.fetch('counts')
  puts <<~EVIDENCE

    ## Verification evidence

    - Compatibility vectors: #{report.fetch('total')} total (#{counts.map { |name, count| "#{name}: #{count}" }.join(', ')}).
    - Release gates: Ruby matrix, tests, RuboCop, package build, installed-gem smoke test, and coverage validation ran on the tagged source.
    - Artifact provenance: see `SHA256SUMS.txt` attached to this release.
  EVIDENCE
end

puts <<~LIMITATIONS

  ## Limitations

  This is a pre-release compatibility slice, not a claim of complete FHIRPath
  conformance. Review the [release support matrix](https://github.com/niccoreyes/fhirpath-ruby/blob/main/docs/support-matrix.md)
  and [conformance workflow](https://github.com/niccoreyes/fhirpath-ruby/blob/main/docs/conformance.md)
  before using it in production.
LIMITATIONS
