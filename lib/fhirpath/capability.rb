# frozen_string_literal: true

module FHIRPath
  # Immutable declaration of the language and host features in use.
  class Capability
    attr_reader :fhirpath, :trial_use, :model_releases, :host_features

    def self.current
      @current ||= new
    end

    def initialize(fhirpath: '2.0.0', trial_use: [], model_releases: [], host_features: [])
      @fhirpath = fhirpath.to_s.freeze
      @trial_use = Array(trial_use).map(&:to_s).freeze
      @model_releases = Array(model_releases).map(&:to_s).freeze
      @host_features = Array(host_features).map(&:to_s).freeze
      freeze
    end

    def supports?(feature)
      trial_use.include?(feature.to_s) || host_features.include?(feature.to_s)
    end

    def to_h
      {
        fhirpath: fhirpath,
        trial_use: trial_use,
        model_releases: model_releases,
        host_features: host_features
      }
    end
  end
end
