#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath'
require 'fhirpath/vector_runner'

path = ARGV.fetch(0) do
  abort "usage: #{File.basename($PROGRAM_NAME)} PATH_TO_JSONL"
end

puts JSON.pretty_generate(FHIRPath::VectorRunner.run(path))
