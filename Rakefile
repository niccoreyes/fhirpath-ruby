# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |task|
  task.libs << 'lib'
  task.libs << 'test'
  task.pattern = 'test/**/*_test.rb'
  task.verbose = true
end

desc 'Run the checked-in compatibility vectors'
task :vectors do
  ruby 'script/run_vectors.rb', 'conformance/core.jsonl'
  ruby 'script/run_vectors.rb', 'conformance/r4.jsonl'
end

task default: :test
