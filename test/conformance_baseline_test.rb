# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'tempfile'
require 'fileutils'
require 'open3'

class CheckConformanceBaselineTest < Minitest::Test
  def setup
    @project_root = File.expand_path('..', __dir__)
    @script = File.join(@project_root, 'script', 'check_conformance_baseline.rb')
    @valid_baseline = {
      'schema_version' => 1,
      'corpus' => 'official-r4',
      'suite' => 'FHIR/fhir-test-cases',
      'suite_commit' => 'ebb15f74f95a4731e59099c4244eeed734c9e447',
      'target' => '2.0.0',
      'model' => 'plain',
      'total' => 100,
      'record_counts' => { 'evaluable' => 50, 'pass' => 30, 'defect' => 5, 'unsupported' => 0, 'host-dependent' => 0,
                           'not-run' => 65 },
      'classification_counts' => { 'pass' => 30, 'defect' => 5, 'unsupported' => 0, 'host-dependent' => 0,
                                   'not-run' => 65 },
      'capability_totals' => {},
      'source_sha' => 'ebb15f74f95a4731e59099c4244eeed734c9e447',
      'corpus_digest' => 'sha256:testdigest'
    }
  end

  def run_script(args)
    stdout, stderr, status = Open3.capture3('bundle', 'exec', 'ruby', @script, *args, chdir: @project_root)
    [stdout, stderr, status]
  end

  def write_report(data)
    Tempfile.create(['report', '.json']) do |f|
      f.write(JSON.pretty_generate(data))
      f.flush
      yield f.path
    end
  end

  def write_baseline(data)
    Tempfile.create(['baseline', '.json']) do |f|
      f.write(JSON.pretty_generate(data))
      f.flush
      yield f.path
    end
  end

  def test_matches_baseline_passes
    report = @valid_baseline.merge('total' => 100, 'record_counts' => @valid_baseline['record_counts'].dup)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        assert_equal 0, status.exitstatus
        assert_match(/baseline-match/, stdout)
      end
    end
  end

  def test_pass_count_increase_is_accepted
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('pass' => 35)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        assert_equal 0, status.exitstatus
        assert_match(/improved/, stdout)
      end
    end
  end

  def test_defect_count_decrease_is_accepted
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('defect' => 2)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        assert_equal 0, status.exitstatus
        assert_match(/improved/, stdout)
      end
    end
  end

  def test_not_run_count_decrease_is_accepted
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('not-run' => 60)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        assert_equal 0, status.exitstatus
        assert_match(/improved/, stdout)
      end
    end
  end

  def test_pass_count_decrease_fails
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('pass' => 25)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_defect_count_increase_fails
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('defect' => 8)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_not_run_count_increase_fails
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('not-run' => 70)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_total_count_change_fails
    report = @valid_baseline.dup
    report['total'] = 105
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_source_sha_drift_fails
    report = @valid_baseline.dup
    report['source_sha'] = 'abcd1234abcd1234abcd1234abcd1234abcd1234'
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_no_baseline_reports_first_run
    report = @valid_baseline
    write_report(report) do |report_path|
      stdout, _stderr, status = run_script(%W[--current #{report_path}])
      assert_equal 0, status.exitstatus
      assert_match(/no-baseline/, stdout)
    end
  end

  def test_strict_mode_rejects_any_change
    report = @valid_baseline.dup
    report['record_counts'] = report['record_counts'].merge('pass' => 31)
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path} --strict])
        refute_equal 0, status.exitstatus
      end
    end
  end

  def test_missing_report_key_fails
    report = @valid_baseline.dup
    report.delete('total')
    write_report(report) do |report_path|
      write_baseline(@valid_baseline) do |baseline_path|
        _stdout, _stderr, status = run_script(%W[--current #{report_path} --baseline #{baseline_path}])
        refute_equal 0, status.exitstatus
      end
    end
  end
end
