# frozen_string_literal: true

require 'optparse'
require 'pathname'

module Undercover
  class Options # rubocop:disable Metrics/ClassLength
    RUN_MODE = [
      RUN_MODE_DIFF_STRICT = :diff_strict, # warn for changed lines
      # RUN_MODE_DIFF_FILES  = :diff_files, # warn for changed whole files
      # RUN_MODE_ALL         = :diff_all, # warn for allthethings
      # RUN_MODE_FILES       = :files # warn for specific files (cli option)
    ].freeze

    OUTPUT_FORMATTERS = [
      OUTPUT_STDOUT = :stdout, # outputs warnings to stdout with exit 1
      # OUTPUT_CIRCLEMATOR = :circlemator # posts warnings as review comments
    ].freeze

    DEFAULT_FILE_INCLUDE_GLOBS = %w[*.rb *.rake *.ru Rakefile].freeze
    DEFAULT_FILE_EXCLUDE_GLOBS = %w[test/* spec/* db/* *_test.rb *_spec.rb].freeze

    attr_accessor :lcov,
                  :path,
                  :git_dir,
                  :compare,
                  :syntax_version,
                  :glob_allow_filters,
                  :glob_reject_filters

    def initialize
      # TODO: use run modes
      # TODO: use formatters
      @run_mode = RUN_MODE_DIFF_STRICT
      @enabled_formatters = [OUTPUT_STDOUT]
      # set defaults
      self.path = '.'
      self.git_dir = '.git'
      self.glob_allow_filters = DEFAULT_FILE_INCLUDE_GLOBS
      self.glob_reject_filters = DEFAULT_FILE_EXCLUDE_GLOBS
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def parse(args)
      args = build_opts(args)

      OptionParser.new do |opts|
        opts.banner = 'Usage: undercover [options]'

        opts.on_tail('-h', '--help', 'Prints this help') do
          puts(opts)
          exit
        end

        opts.on_tail('--version', 'Show version') do
          puts VERSION
          exit
        end

        lcov_path_option(opts)
        project_path_option(opts)
        git_dir_option(opts)
        compare_option(opts)
        ruby_syntax_option(opts)
        file_filters(opts)
      end.parse(args)

      guess_lcov_path unless lcov
      self
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    private

    def build_opts(args)
      project_options.concat(args)
    end

    def project_options
      args_from_options_file(project_options_file)
    end

    def args_from_options_file(path)
      return [] unless File.exist?(path)

      File.read(path).split('\n').flat_map(&:split)
    end

    def project_options_file
      './.undercover'
    end

    def lcov_path_option(parser)
      parser.on('-l', '--lcov path', 'LCOV report file path') do |path|
        self.lcov = path
      end
    end

    def project_path_option(parser)
      parser.on('-p', '--path path', 'Project directory') do |path|
        self.path = path
      end
    end

    def git_dir_option(parser)
      desc = 'Override `.git` with a custom directory'
      parser.on('-g', '--git-dir dir', desc) do |dir|
        self.git_dir = dir
      end
    end

    def compare_option(parser)
      desc = 'Generate coverage warnings for all changes after `ref`'
      parser.on('-c', '--compare ref', desc) do |ref|
        self.compare = ref
      end
    end

    def ruby_syntax_option(parser)
      versions = Imagen::AVAILABLE_RUBY_VERSIONS.sort.join(', ')
      desc = "Ruby syntax version, one of: #{versions}"
      parser.on('-r', '--ruby-syntax ver', desc) do |version|
        self.syntax_version = version.strip
      end
    end

    def guess_lcov_path
      cwd = Pathname.new(File.expand_path(path))
      self.lcov = File.join(cwd, 'coverage', 'lcov', "#{cwd.split.last}.lcov")
    end

    def file_filters(parser)
      desc = 'Include files matching specified glob patterns (comma separated). ' \
             "Defaults to '#{DEFAULT_FILE_INCLUDE_GLOBS.join(',')}'"
      parser.on('-f', '--include-files globs', desc) do |comma_separated_globs|
        self.glob_allow_filters = comma_separated_globs.strip.split(',')
      end

      desc = 'Skip files matching specified glob patterns (comma separated). Empty by default.'
      parser.on('-x', '--exclude-files globs', desc) do |comma_separated_globs|
        self.glob_reject_filters = comma_separated_globs.strip.split(',')
      end
    end
  end
end
