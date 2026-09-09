# frozen_string_literal: true

require 'json'
require 'digest'

module FHIRPath
  module Conformance
    # Validates a conformance corpus against a strict, deterministic contract.
    #
    # A corpus is an array of vector records (typically produced by the importer
    # as one JSON object per line). The validator enforces record shape, an
    # immutable upstream provenance SHA, explicit allowed classifications,
    # required conditional fields, supported model values, source-path
    # containment, unique IDs, and stable (ascending id) ordering. It also
    # computes a canonical corpus digest that is stable regardless of record
    # ordering, so two equivalent imports produce byte-identical normalized
    # output and an identical digest.
    class CorpusValidator
      CLASSIFICATIONS = %w[pass defect unsupported host-dependent not-run].freeze
      SUPPORTED_MODELS = %w[plain r4].freeze
      SHA_PATTERN = /\A[0-9a-f]{7,40}\z/
      # Mutable references that can move over time and must never be used to
      # pin a corpus: branch names, HEAD, and version-style tags.
      MUTABLE_COMMIT = /\A(?:master|main|HEAD|latest|v?\d+(?:\.\d+)+)\z/i

      REQUIRED_FIELDS = %w[
        id suite suite_commit expression model host_features target capability
        expected resource variables origin
      ].freeze
      ORIGIN_REQUIRED_FIELDS = %w[suite suite_commit].freeze

      class CorpusError < StandardError; end

      def self.validate(records, baseline: nil)
        new(records, baseline).run
      end

      def self.validate_file(path, baseline: nil)
        new(load_records(path), baseline).run.merge(source: path)
      end

      def self.load_records(path)
        File.foreach(path).with_index(1).each_with_object([]) do |(line, line_number), records|
          next if line.strip.empty?

          begin
            records << JSON.parse(line)
          rescue JSON::ParserError => e
            raise CorpusError, "line #{line_number}: malformed JSON record: #{e.message}"
          end
        end
      end

      def initialize(records, baseline = nil)
        @records = Array(records)
        @baseline = baseline
        @errors = []
      end

      def run
        validate_records!
        metadata = {
          total: @records.length,
          record_counts: record_counts,
          capability_totals: capability_totals,
          corpus_suite: corpus_suite,
          source_sha: source_sha,
          digest: digest
        }
        { status: @errors.empty? ? 'pass' : 'fail',
          valid: @errors.empty?,
          errors: @errors }.merge(metadata)
      end

      private

      def validate_records!
        validate_ids!
        validate_schema!
        validate_commit!
        validate_classification!
        validate_models!
        validate_paths!
        validate_ordering!
      end

      def validate_ids!
        @records.group_by { |record| record.is_a?(Hash) ? record['id'] : nil }.each do |id, records|
          next unless id

          @errors << "duplicate id #{id.inspect}" if records.length > 1
        end
      end

      def validate_schema!
        @records.each_with_index do |record, index|
          unless record.is_a?(Hash)
            @errors << "record #{index + 1}: must be a JSON object"
            next
          end

          REQUIRED_FIELDS.each do |field|
            @errors << "record #{label(record)}: missing required field #{field.inspect}" unless record.key?(field)
          end

          origin = record['origin']
          if origin && !origin.is_a?(Hash)
            @errors << "record #{label(record)}: origin must be a JSON object"
          elsif origin
            ORIGIN_REQUIRED_FIELDS.each do |field|
              @errors << "record #{label(record)}: origin missing #{field.inspect}" unless origin.key?(field)
            end
            unless origin.key?('case') || origin.key?('path')
              @errors << "record #{label(record)}: origin requires a case or path"
            end
          end
        end
      end

      def validate_commit!
        @records.each do |record|
          next unless record.is_a?(Hash)

          add_commit_error(record, record['suite_commit'], 'suite_commit')
          add_commit_error(record, record.dig('origin', 'suite_commit'), 'origin.suite_commit')
        end
      end

      def add_commit_error(record, value, field)
        return if value.nil?

        valid = !value.to_s.empty? && !MUTABLE_COMMIT.match?(value.to_s) && SHA_PATTERN.match?(value.to_s)
        return if valid

        @errors << "record #{label(record)}: #{field} #{value.inspect} is not an immutable SHA"
      end

      def validate_classification!
        @records.each do |record|
          next unless record.is_a?(Hash)

          classification = record['classification']
          next if classification.nil?

          unless CLASSIFICATIONS.include?(classification)
            @errors << "record #{label(record)}: invalid classification #{classification.inspect} " \
                       "(allowed: #{CLASSIFICATIONS.join(', ')})"
          end
          next unless classification == 'not-run'

          reason = record['not_run_reason']
          next unless reason.nil? || reason.to_s.empty?

          @errors << "record #{label(record)}: not-run requires not_run_reason"
        end
      end

      def validate_models!
        @records.each do |record|
          next unless record.is_a?(Hash)

          model = record['model']
          next if model.nil?
          next if SUPPORTED_MODELS.include?(model.to_s.downcase)

          @errors << "record #{label(record)}: unsupported model #{model.inspect} " \
                     "(allowed: #{SUPPORTED_MODELS.join(', ')})"
        end
      end

      def validate_paths!
        @records.each do |record|
          next unless record.is_a?(Hash)

          %w[input_fixture fixture_source].each do |field|
            value = record[field]
            next unless value && path_escapes?(value)

            @errors << "record #{label(record)}: #{field} escapes source root: #{value}"
          end
          origin_path = record.dig('origin', 'path')
          if origin_path && path_escapes?(origin_path)
            @errors << "record #{label(record)}: origin.path escapes source root: #{origin_path}"
          end
        end
      end

      def validate_ordering!
        ids = @records.filter_map { |record| record['id'] if record.is_a?(Hash) && record['id'] }
        return if ids == ids.sort

        @errors << 'records are not in stable (ascending id) order'
      end

      def path_escapes?(value)
        path = value.to_s
        segments = path.split(%r{[\\/]})
        path.start_with?('/') || segments.include?('..')
      end

      def label(record)
        id = record.is_a?(Hash) ? record['id'] : nil
        id ? "id=#{id.inspect}" : 'unnamed'
      end

      def record_counts
        counts = counts_template
        @records.each do |record|
          next unless record.is_a?(Hash)

          increment_count(counts, record['classification'])
        end
        counts
      end

      def counts_template
        { 'evaluable' => 0 }.merge(CLASSIFICATIONS.to_h { |name| [name, 0] })
      end

      def capability_totals
        @records.each_with_object({}) do |record, totals|
          next unless record.is_a?(Hash)

          capability = record['capability'] || 'unspecified'
          entry = totals[capability] ||= { total: 0, counts: counts_template }
          entry[:total] += 1
          increment_count(entry[:counts], record['classification'])
        end
      end

      def increment_count(counts, classification)
        if classification && counts.key?(classification)
          counts[classification] += 1
        elsif classification.nil?
          counts['evaluable'] += 1
        end
      end

      def source_sha
        record = @records.find do |candidate|
          candidate.is_a?(Hash) && candidate['suite_commit'] && !candidate['suite_commit'].to_s.empty?
        end
        record && record['suite_commit']
      end

      def corpus_suite
        record = @records.find do |candidate|
          candidate.is_a?(Hash) && candidate['suite'] && !candidate['suite'].to_s.empty?
        end
        record && record['suite']
      end

      def digest
        canonical = @records.filter_map { |record| record['id'] ? record : nil }
                            .sort_by { |record| record['id'].to_s }
                            .map { |record| JSON.generate(canonical_structure(record)) }
                            .join("\n")
        "sha256:#{Digest::SHA256.hexdigest(canonical)}"
      end

      def canonical_structure(value)
        case value
        when Hash
          value.keys.sort.each_with_object({}) { |key, out| out[key] = canonical_structure(value[key]) }
        when Array
          value.map { |item| canonical_structure(item) }
        else
          value
        end
      end
    end
  end
end
