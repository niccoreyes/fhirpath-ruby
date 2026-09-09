# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/conformance/importer'
require 'tmpdir'
require 'fileutils'

class FHIRPathImporterXmlFixtureIntegrationTest < Minitest::Test
  # An XML-only official fixture (no matching JSON) must become an executable
  # FHIR JSON resource via the converter, not be classified not-run merely
  # because no same-named JSON file exists.
  def test_xml_only_fixture_becomes_executable_resource
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4'))
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="patient-name-given" inputfile="patient-example.xml">
              <expression>name.given</expression>
            </test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'r4', 'patient-example.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="example"/>
          <active value="true"/>
          <name>
            <family value="Chalmers"/>
            <given value="Peter"/>
            <given value="James"/>
          </name>
        </Patient>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'tests.xml',
        suite_commit: 'abc123',
        fixture_root: 'r4',
        case_ids: ['patient-name-given']
      ).import

      record = records.first
      refute_equal 'not-run', record['classification'],
                   'XML-only fixture should not be classified not-run'
      refute_nil record['resource'], 'XML-only fixture must produce a resource'
      assert_equal 'Patient', record['resource']['resourceType']
      assert_equal 'example', record['resource']['id']
      assert_equal true, record['resource']['active']
      assert_equal 'Chalmers', record['resource']['name']['family']
      assert_equal 'xml-to-json', record['fixture_conversion']
      assert_includes record['fixture_source'], 'patient-example.xml'
    end
  end

  # When a verified JSON fixture exists for an XML fixture, the importer must
  # resolve to that verified JSON rather than converting (trust parity, not
  # basename).
  def test_xml_fixture_prefers_verified_json_when_present
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4'))
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="patient-name-given" inputfile="patient-example.xml">
              <expression>name.given</expression>
            </test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'r4', 'patient-example.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="example"/>
          <name>
            <given value="Verified"/>
          </name>
        </Patient>
      XML
      File.write(File.join(root, 'r4', 'patient-example.json'),
                 JSON.generate({ 'resourceType' => 'Patient', 'id' => 'example',
                                 'name' => [{ 'given' => ['Verified'] }] }))

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'tests.xml',
        suite_commit: 'abc123',
        fixture_root: 'r4',
        case_ids: ['patient-name-given']
      ).import

      record = records.first
      assert_equal 'Verified', record['resource']['name'].first['given'].first
      assert_nil record['fixture_conversion'], 'verified JSON should not be converted'
      assert_includes record['fixture_source'], 'patient-example.json'
    end
  end

  # A same-basename JSON that is a structurally different resource instance
  # (different id) must NOT be trusted; the importer falls back to conversion.
  def test_xml_fixture_rejects_same_basename_different_resource
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4'))
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="patient-name-given" inputfile="patient-example.xml">
              <expression>name.given</expression>
            </test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'r4', 'patient-example.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="expected-id"/>
          <name>
            <given value="FromXml"/>
          </name>
        </Patient>
      XML
      File.write(File.join(root, 'r4', 'patient-example.json'),
                 JSON.generate({ 'resourceType' => 'Patient', 'id' => 'other-id',
                                 'name' => [{ 'given' => ['FromJson'] }] }))

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'tests.xml',
        suite_commit: 'abc123',
        fixture_root: 'r4',
        case_ids: ['patient-name-given']
      ).import

      record = records.first
      assert_equal 'FromXml', record['resource']['name']['given']
      assert_equal 'xml-to-json', record['fixture_conversion']
    end
  end

  # Repeated <contained> elements (one resource each) must collapse into a flat
  # array of resource hashes -- [org1, org2] -- never nested arrays such as
  # [[org1], [org2]]. Regression coverage for repeated, not just single,
  # <contained> elements.
  def test_xml_converter_handles_repeated_contained_elements
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4'))
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="two-contained" inputfile="two-contained.xml">
              <expression>contained</expression>
            </test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'r4', 'two-contained.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="example"/>
          <contained>
            <Organization>
              <id value="org1"/>
              <name value="Acme Healthcare"/>
            </Organization>
          </contained>
          <contained>
            <Organization>
              <id value="org2"/>
              <name value="Globex Health"/>
            </Organization>
          </contained>
        </Patient>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'tests.xml',
        suite_commit: 'abc123',
        fixture_root: 'r4',
        case_ids: ['two-contained']
      ).import

      contained = records.first['resource']['contained']
      assert_equal 2, contained.length
      refute contained.any?(Array),
             'repeated <contained> elements must yield a flat array of resources, not nested arrays'
      assert_equal 'Organization', contained[0]['resourceType']
      assert_equal 'org1', contained[0]['id']
      assert_equal 'Organization', contained[1]['resourceType']
      assert_equal 'org2', contained[1]['id']
    end
  end

  # An unsupported XML structure must fail closed (classification not-run) with
  # an explicit reason rather than emitting a silently wrong resource.
  def test_unsupported_xml_structure_fails_closed
    Dir.mktmpdir('fhirpath-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4'))
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="integer-bad" inputfile="bad-integer.xml">
              <expression>active</expression>
            </test>
          </group>
        </tests>
      XML
      File.write(File.join(root, 'r4', 'bad-integer.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <telecom>
            <rank value="not-an-integer"/>
          </telecom>
        </Patient>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root,
        suite_path: 'tests.xml',
        suite_commit: 'abc123',
        fixture_root: 'r4',
        case_ids: ['integer-bad']
      ).import

      record = records.first
      assert_equal 'not-run', record['classification']
      refute_nil record['not_run_reason']
      assert_includes record['not_run_reason'], 'unsupported XML structure'
    end
  end
end
