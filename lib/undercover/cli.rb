# frozen_string_literal: true

require 'undercover'
require 'rainbow'

module Undercover
  module CLI
    # TODO: Report calls >parser< for each file instead of
    # traversing the whole project at first!

    WARNINGS_TO_S = {
      stale_coverage: Rainbow('🚨 WARNING: Coverage data is older than your ' \
                              'latest changes and results might be incomplete. ' \
                              'Re-run tests to update').yellow,
      no_changes: Rainbow('✅ No reportable changes').green
    }.freeze
    def self.run(args)
      opts = Undercover::Options.new.parse(args)
      syntax_version(opts.syntax_version)

      run_report(opts)
    end

    def self.run_report(opts)
      coverage_path = opts.simplecov_resultset || opts.lcov
      return handle_missing_coverage_path(opts) if coverage_path.nil?
      return handle_missing_file(coverage_path) unless File.exist?(coverage_path)

      report = Undercover::Report.new(changeset(opts), opts).build
      handle_report_validation(report, coverage_path)
    end

    def self.handle_missing_coverage_path(opts)
      puts Rainbow('❌ ERROR: No coverage report found. Checked default paths:').red
      puts Rainbow('  - ./coverage/coverage.json (SimpleCov)').red
      puts Rainbow("  - ./coverage/lcov/#{Pathname.new(File.expand_path(opts.path)).split.last}.lcov (LCOV)").red
      puts Rainbow('Set a custom path with --lcov or --simplecov option').red
      1
    end

    def self.handle_missing_file(coverage_path)
      puts Rainbow("❌ ERROR: Coverage report not found at: #{coverage_path}").red
      1
    end

    def self.handle_report_validation(report, coverage_path)
      error = report.validate(coverage_path)
      if error
        puts(WARNINGS_TO_S[error])
        return 0 if error == :no_changes
      end

      flagged = report.flagged_results
      puts Undercover::Formatter.new(flagged)
      flagged.any? ? 1 : 0
    end

    def self.syntax_version(version)
      return unless version

      Imagen.parser_version = version
    end

    def self.changeset(opts)
      git_dir = File.join(opts.path, opts.git_dir)
      filter_set = Undercover::FilterSet.new(opts.glob_allow_filters, opts.glob_reject_filters)
      Undercover::Changeset.new(git_dir, opts.compare, filter_set)
    end
  end
end
