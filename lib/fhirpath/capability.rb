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

    attr_reader :fhirpath, :trial_use, :model_releases, :host_features, :capability_set

    def self.current
      @current ||= new
    end

    def initialize(fhirpath: '2.0.0', trial_use: [], model_releases: ['R4'], host_features: [],
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
      model_releases.include?(release.to_s.upcase)
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
