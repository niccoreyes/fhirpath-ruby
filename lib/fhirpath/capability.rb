# frozen_string_literal: true

module FHIRPath
  # Immutable declaration of the language and host features in use.
  class Capability
    CAPABILITY_SET = %w[
      parser immutable-ast collection-evaluation plain-model-navigation
      primitive-values arithmetic comparison-and-equivalence boolean-logic
      union-membership-and-type-operators collection-functions focus-variables
      external-constants custom-functions compiled-expression-reuse fhir-r4-model
      structured-errors
    ].freeze

    # Named FHIRPath 3.0.0 STU3 subset the standard registry ships by default.
    # `Capability.current` reports it in `trial_use` (not in `capability_set`),
    # so the capability report never mixes STU3 behavior silently into the
    # normative 2.0.0 claims: `fhirpath` stays `2.0.0` and the capability set
    # above stays unchanged. The marker declares the shipped surface; it does
    # not gate `FunctionRegistry.standard` (see docs/api.md Capability).
    STU3_AGGREGATE_FUNCTIONS = 'stu3-aggregate-functions'

    attr_reader :fhirpath, :trial_use, :model_releases, :host_features, :capability_set

    def self.current
      @current ||= new
    end

    def initialize(fhirpath: '2.0.0', trial_use: [STU3_AGGREGATE_FUNCTIONS], model_releases: ['R4'], host_features: [],
                   capability_set: CAPABILITY_SET)
      @fhirpath = fhirpath.to_s.freeze
      @trial_use = Array(trial_use).map(&:to_s).freeze
      @model_releases = Array(model_releases).map(&:to_s).freeze
      @host_features = Array(host_features).map(&:to_s).freeze
      @capability_set = Array(capability_set).map(&:to_s).freeze
      freeze
    end

    def supports?(feature)
      trial_use.include?(feature.to_s) || host_features.include?(feature.to_s) ||
        supports_model?(feature)
    end

    def supports_model?(release)
      model_releases.any? { |configured_release| configured_release.casecmp?(release.to_s) }
    end

    def to_h
      {
        fhirpath: fhirpath,
        capability_set: capability_set,
        trial_use: trial_use,
        model_releases: model_releases,
        host_features: host_features
      }
    end
  end
end
