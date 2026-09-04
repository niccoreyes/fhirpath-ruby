# frozen_string_literal: true

if ENV['COVERAGE']
  require 'coverage'
  require 'fileutils'
  require 'json'

  Coverage.start(lines: true)
  at_exit do
    files = Coverage.result.each_with_object([]) do |(path, lines), result|
      next unless path.include?('/lib/fhirpath')

      line_counts = lines.is_a?(Hash) ? lines.fetch(:lines, []) : lines
      executable = line_counts.select { |line| line.is_a?(Integer) }
      result << {
        'path' => path,
        'total_lines' => executable.length,
        'covered_lines' => executable.count(&:positive?)
      }
    end
    FileUtils.mkdir_p('coverage')
    File.write('coverage/summary.json', JSON.pretty_generate('files' => files))
  end
end

require 'minitest/autorun'
require 'fhirpath'
