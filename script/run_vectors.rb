#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath'
require 'fhirpath/vector_runner'

path = ARGV.fetch(0) do
  abort "usage: #{File.basename($PROGRAM_NAME)} PATH_TO_JSONL"
end

report = FHIRPath::VectorRunner.run(path)
puts JSON.pretty_generate(report)

# A release may document unsupported or host-dependent cases, but it must not
# ship known defects or silently skipped cases as conformance evidence.
blocked = report[:counts].slice('defect', 'not-run')
exit 1 if blocked.values.any?(&:positive?)
