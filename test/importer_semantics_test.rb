# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/conformance/importer'
require 'fileutils'
require 'tmpdir'

class FHIRPathImporterSemanticsTest < Minitest::Test
  def test_parse_invalid_syntax_maps_to_parse_error
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="syntax-case">
              <expression invalid="syntax">|||bad|||</expression>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      refute record['error'].key?('code'), 'expected error should not include code for phase matching'
      assert_equal 'FHIRPath::ParseError', record['error']['class']
    end
  end

  def test_parse_invalid_execution_maps_to_generic_error
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="execution-case">
              <expression invalid="execution">not-a-real-type</expression>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      refute record['error'].key?('code'), 'expected error should not include code for phase matching'
      assert_equal 'FHIRPath::EvaluationError', record['error']['class']
    end
  end

  def test_parse_output_preserves_boolean_case
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="bool-case">
              <expression>true</expression>
              <output type="boolean">TRUE</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal [true], record['expected']
    end
  end

  def test_parse_output_preserves_integer_value
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="int-case">
              <expression>1 + 2</expression>
              <output type="integer">3</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal [3], record['expected']
      assert_equal Integer, record['expected'].first.class
    end
  end

  def test_parse_output_preserves_decimal_as_string_for_precision
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="decimal-case">
              <expression>1.0 / 3.0</expression>
              <output type="decimal">0.3333333333333333</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal ['0.3333333333333333'], record['expected']
      assert_equal String, record['expected'].first.class
    end
  end

  def test_parse_output_preserves_string_whitespace
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="string-case">
              <expression>'  hello  '</expression>
              <output type="string">  hello  </output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal ['  hello  '], record['expected']
    end
  end

  def test_parse_output_with_unknown_type_creates_tagged_value
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="quantity-case">
              <expression>5 kg</expression>
              <output type="quantity">5 kg</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      expected = record['expected'].first
      assert_equal 'quantity', expected['$type']
      assert_equal '5 kg', expected['value']
    end
  end

  def test_empty_output_array_when_no_output_element
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="no-output-case">
              <expression>{}.name</expression>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal [], record['expected']
    end
  end

  def test_multiple_output_elements_creates_array
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="multi-output-case">
              <expression>(1 | 2)</expression>
              <output type="integer">1</output>
              <output type="integer">2</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      assert_equal [1, 2], record['expected']
      assert_equal Integer, record['expected'].first.class
      assert_equal Integer, record['expected'].last.class
    end
  end

  def test_temporal_output_with_date_type
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="date-case">
              <expression>'2024-01-15'</expression>
              <output type="date">2024-01-15</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      expected = record['expected'].first
      assert_equal 'date', expected['$type']
      assert_equal '2024-01-15', expected['value']
    end
  end

  def test_temporal_output_with_datetime_type
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="datetime-case">
              <expression>'2024-01-15T10:30:00Z'</expression>
              <output type="dateTime">2024-01-15T10:30:00Z</output>
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import

      record = records.first
      expected = record['expected'].first
      assert_equal 'dateTime', expected['$type']
      assert_equal '2024-01-15T10:30:00Z', expected['value']
    end
  end
end
