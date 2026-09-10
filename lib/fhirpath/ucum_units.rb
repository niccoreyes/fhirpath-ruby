# frozen_string_literal: true

module FHIRPath
  module UCUM
    # Atom table for the deliberately bounded, dependency-free UCUM subset.
    #
    # Each entry maps an atom symbol to its dimension map and its scale relative
    # to that dimension's base atom (`m`, `g`, `L`, `mol`, `s`). Unknown atoms
    # are rejected; callers must not interpret this subset as complete UCUM
    # conformance.
    UNIT_ATOMS = {
      '1' => [{}, '1'],
      'm' => [{ length: 1 }, '1'],
      'cm' => [{ length: 1 }, '0.01'],
      'mm' => [{ length: 1 }, '0.001'],
      'km' => [{ length: 1 }, '1000'],
      'g' => [{ mass: 1 }, '1'],
      'kg' => [{ mass: 1 }, '1000'],
      'mg' => [{ mass: 1 }, '0.001'],
      'Mg' => [{ mass: 1 }, '1000000'],
      'ug' => [{ mass: 1 }, '0.000001'],
      'ng' => [{ mass: 1 }, '0.000000001'],
      'L' => [{ volume: 1 }, '1'],
      'mL' => [{ volume: 1 }, '0.001'],
      'ML' => [{ volume: 1 }, '1000000'],
      'uL' => [{ volume: 1 }, '0.000001'],
      'mol' => [{ amount: 1 }, '1'],
      'mmol' => [{ amount: 1 }, '0.001'],
      'umol' => [{ amount: 1 }, '0.000001'],
      's' => [{ time: 1 }, '1'],
      'min' => [{ time: 1 }, '60'],
      'h' => [{ time: 1 }, '3600'],
      # FHIRPath temporal units (not standard UCUM)
      'd' => [{ time: 1 }, '86400'],
      'wk' => [{ time: 1 }, '604800'],
      'mo' => [{ time: 1 }, '2629746'],
      'a' => [{ time: 1 }, '31556952'],
      'ms' => [{ time: 1 }, '0.001'],
      # UCUM alternative-symbol atoms required by the official shared suite.
      '[in_i]' => [{ length: 1 }, '0.0254'],
      '[lb_av]' => [{ mass: 1 }, '453.59237'],
      '[s]' => [{ time: 1 }, '1'],
      # FHIRPath calendar durations, written as unit names ("1 'month'").
      'year' => [{ time: 1 }, '31556952'],
      'month' => [{ time: 1 }, '2629746'],
      'week' => [{ time: 1 }, '604800'],
      'day' => [{ time: 1 }, '86400'],
      'hour' => [{ time: 1 }, '3600'],
      'minute' => [{ time: 1 }, '60'],
      'second' => [{ time: 1 }, '1'],
      'millisecond' => [{ time: 1 }, '0.001']
    }.freeze
  end
end
