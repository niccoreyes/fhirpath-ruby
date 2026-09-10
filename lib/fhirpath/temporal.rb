# frozen_string_literal: true

require 'date'
require 'time'

module FHIRPath
  # A `Date`, `DateTime`, or `Time` value together with the precision of the
  # literal it was parsed from. FHIRPath temporal values can carry any
  # precision from year down to millisecond, but Ruby's `Date`/`DateTime`/
  # `Time` cannot represent "2014" as distinct from "2014-01-01". Literals at
  # the natural precision of their Ruby class are returned unwrapped; every
  # other literal is wrapped here so that equality and comparison can return an
  # empty collection when two values have different precision instead of
  # silently comparing defaulted components (FHIRPath 2.0.0, 5.6).
  class Temporal
    # Precision codes used by `precision()`, `lowBoundary()`, and
    # `highBoundary()`.
    YEAR = 4
    MONTH = 6
    DAY = 8
    HOUR = 10
    MINUTE = 12
    SECOND = 14
    MILLISECOND = 17
    TIME_HOUR = 2
    TIME_MINUTE = 4
    TIME_SECOND = 6
    TIME_MILLISECOND = 9

    KINDS = %i[date datetime time].freeze

    attr_reader :value, :kind, :precision, :timezone

    def initialize(value, kind:, precision:, timezone: nil)
      raise ArgumentError, "unsupported temporal kind: #{kind}" unless KINDS.include?(kind)

      @value = value
      @kind = kind
      @precision = precision
      @timezone = timezone
      freeze
    end

    def date?
      kind == :date
    end

    def datetime?
      kind == :datetime
    end

    def time?
      kind == :time
    end

    def to_ruby
      value
    end

    def to_h
      { kind: kind, precision: precision, value: value }.freeze
    end

    def year
      value.year
    end

    def month
      value.respond_to?(:month) ? value.month : nil
    end

    def day
      value.respond_to?(:day) ? value.day : nil
    end

    def hour
      value.respond_to?(:hour) ? value.hour : nil
    end

    def min
      value.respond_to?(:min) ? value.min : nil
    end

    def sec
      value.respond_to?(:sec) ? value.sec : nil
    end

    def usec
      value.respond_to?(:usec) ? value.usec : 0
    end

    def ==(other)
      other.is_a?(Temporal) && kind == other.kind && precision == other.precision &&
        value == other.value
    end
    alias eql? ==

    # Precision used for comparison and equality. Sub-second precision is not a
    # distinct comparison level: `@2012-04-15T15:30:31.1` is compared
    # numerically against `@2012-04-15T15:30:31` rather than being treated as
    # indeterminate, while `precision` still reports the written form (17).
    def comparison_precision
      case kind
      when :datetime then [precision, SECOND].min
      when :time then [precision, TIME_SECOND].min
      else precision
      end
    end

    def hash
      [self.class, kind, precision, value].hash
    end

    def <=>(other)
      return nil unless other.is_a?(Temporal)

      value <=> other.value
    end

    # FHIRPath literal form, e.g. "@2014-12" or "@T10:30:59.999".
    def to_s
      "@#{TemporalRenderer.render(kind, precision, value)}"
    end

    def inspect
      "#<#{self.class.name} #{self}>"
    end
  end

  # Renders temporal values at a given precision using FHIRPath literal syntax,
  # omitting any component below that precision ("@2014-12", "@T10:30:59.999").
  module TemporalRenderer
    module_function

    def render(kind, precision, value)
      case kind
      when :date then render_date(precision, value)
      when :time then render_time(precision, value)
      when :datetime then render_datetime(precision, value)
      end
    end

    def render_date(precision, value)
      return format('%04d', value.year) if precision <= Temporal::YEAR
      return format('%04d-%02d', value.year, value.month) if precision <= Temporal::MONTH

      format('%04d-%02d-%02d', value.year, value.month, value.day)
    end

    def render_time(precision, value)
      text = +format('T%02d', value.hour)
      return text if precision <= Temporal::TIME_HOUR

      text << format(':%02d', value.min)
      return text if precision <= Temporal::TIME_MINUTE

      text << format(':%02d', value.sec)
      return text if precision <= Temporal::TIME_SECOND

      "#{text}.#{format('%03d', value.usec / 1000)}"
    end

    def render_datetime(precision, value)
      return render_date(precision, value) if precision <= Temporal::DAY

      fraction = value.sec_fraction
      text = +format('%04d-%02d-%02dT%02d', value.year, value.month, value.day, value.hour)
      if precision >= Temporal::MINUTE
        text << format(':%02d', value.min)
        text << format(':%02d', value.sec) if precision >= Temporal::SECOND
        text << format('.%03d', (fraction * 1000).to_i) if precision > Temporal::SECOND
      end
      text << offset_suffix(value)
      text
    end

    def offset_suffix(value)
      return '' if value.offset.zero?

      value.zone.to_s
    end
  end
end
