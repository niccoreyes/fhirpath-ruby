#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

name = ARGV.fetch(0, 'fhirpath')
version = ARGV.fetch(1) { abort 'usage: verify_rubygems_publication.rb GEM_NAME VERSION' }
uri = URI("https://rubygems.org/api/v1/gems/#{URI::DEFAULT_PARSER.escape(name)}.json")
attempts = Integer(ENV.fetch('RUBYGEMS_VERIFY_ATTEMPTS', '30'), 10)
interval = Integer(ENV.fetch('RUBYGEMS_VERIFY_INTERVAL', '10'), 10)

attempts.times do |attempt|
  response = Net::HTTP.get_response(uri)
  if response.is_a?(Net::HTTPSuccess)
    payload = JSON.parse(response.body)
    if payload['version'] == version
      puts "RubyGems verified #{name} #{version} after #{attempt + 1} attempt(s)"
      exit 0
    end
  end

  sleep interval unless attempt == attempts - 1
end

abort "RubyGems did not expose #{name} #{version} within the verification window"
