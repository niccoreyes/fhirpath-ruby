# frozen_string_literal: true

require 'json'

path = ARGV.fetch(0, 'coverage/summary.json')
report = JSON.parse(File.read(path))
files = report.fetch('files')
total = files.sum { |file| file.fetch('total_lines') }
covered = files.sum { |file| file.fetch('covered_lines') }
percentage = total.zero? ? 0.0 : (covered.to_f * 100 / total)

abort 'coverage report contains no library files' if files.empty? || total.zero?

puts format('Coverage: %.1f%% (%d/%d executable lines)', percentage, covered, total)
