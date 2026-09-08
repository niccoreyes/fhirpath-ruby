#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/fhirpath/version'

# Files to check for version consistency (current-facing docs only)
DOC_FILES = [
  'README.md',
  'docs/api.md',
  'docs/feature-matrix.md',
  'docs/support-matrix.md',
  'docs/release-checklist.md'
].freeze

# Current library version
LIB_VERSION = FHIRPath::VERSION

# Collect drift sources
drift_sources = []

DOC_FILES.each do |doc_file|
  file_path = File.join(__dir__, '..', doc_file)
  unless File.exist?(file_path)
    puts "WARNING: #{doc_file} not found"
    next
  end

  content = File.read(file_path)
  # Look for version patterns like `0.2.0.pre[0-9]+`
  content.scan(/0\.2\.0\.pre\d+/) do |match|
    if match != LIB_VERSION
      # Find line number for better reporting
      line_num = content.each_line.with_index(1).find { |line, _| line.include?(match) }&.last || '?'
      drift_sources << {
        file: doc_file,
        line: line_num,
        value: match,
        expected: LIB_VERSION
      }
    end
  end
end

# Special check for CHANGELOG - only check the [Unreleased] link, not historical entries
changelog_file = File.join(__dir__, '..', 'CHANGELOG.md')
if File.exist?(changelog_file)
  content = File.read(changelog_file)

  # Check for the [Unreleased] comparison link
  link_pattern = %r{\[Unreleased\]: https://github\.com/niccoreyes/fhirpath-ruby/compare/v0\.2\.0\.pre(\d+)\.\.HEAD}
  content.scan(link_pattern) do |match|
    link_version = "0.2.0.pre#{match}"
    if link_version != LIB_VERSION
      # Find line number for the [Unreleased] link
      line_num = content.each_line.with_index(1).find { |line, _| line.start_with?('[Unreleased]:') }&.last || '?'
      drift_sources << {
        file: 'CHANGELOG.md',
        line: line_num,
        value: link_version,
        expected: LIB_VERSION,
        type: 'stale current comparison link'
      }
    end
  end
end

if drift_sources.empty?
  puts "SUCCESS: All documentation versions match library version (#{LIB_VERSION})"
  exit 0
else
  puts 'ERROR: Documentation version drift detected!'
  puts "Library version: #{LIB_VERSION}"
  puts ''
  drift_sources.each do |source|
    line_info = source[:line] ? ":#{source[:line]}" : ''
    type_info = source[:type] ? " (#{source[:type]})" : ''
    puts "  - #{source[:file]}#{line_info}: has '#{source[:value]}', expected '#{source[:expected]}'#{type_info}"
  end
  exit 1
end
