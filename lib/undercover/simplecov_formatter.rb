# frozen_string_literal: true

require 'simplecov_json_formatter'

# Patch ResultExporter to allow setting a custom export_path
module SimpleCovJSONFormatter
  class ResultExporter
    def export_path
      # :nocov:
      File.join(SimpleCov.coverage_path, SimpleCov::Formatter::Undercover.output_filename || FILENAME)
      # :nocov:
    end
  end
end

module SimpleCov
  class << self
    attr_accessor :filtered_files

    alias filtered_uncached filtered

    def filtered(files)
      @filtered_files ||= Set.new
      original_files = files.dup
      filtered_uncached(files).tap do |filtered_files|
        @filtered_files += (original_files.map(&:filename) - filtered_files.map(&:filename))
      end
    end
  end
end

module Undercover
  class ResultHashFormatterWithRoot < SimpleCovJSONFormatter::ResultHashFormatter
    def format
      formatted_result[:meta] = {timestamp: @result.created_at.to_i}
      format_files
      add_undercover_meta_fields
      add_ignored_files
      formatted_result
    end

    private

    def add_undercover_meta_fields
      formatted_result.tap do |result|
        result[:meta].merge!(simplecov_root: SimpleCov.root)
      end
    end

    def add_ignored_files
      ignored_files = SimpleCov.filtered_files&.map do |file|
        file.delete_prefix("#{SimpleCov.root}/")
      end || []

      formatted_result[:meta][:ignored_files] = ignored_files
    end

    # format_files uses relative path as keys, as opposed to the superclass method
    def format_files
      formatted_result[:coverage] ||= {}
      @result.files.each do |source_file|
        path = source_file.project_filename.delete_prefix('/')
        formatted_result[:coverage][path] = format_source_file(source_file)
      end
    end
  end

  class UndercoverSimplecovFormatter < SimpleCov::Formatter::JSONFormatter
    class << self
      attr_accessor :output_filename
    end

    def format_result(result)
      result_hash_formater = ResultHashFormatterWithRoot.new(result)
      result_hash_formater.format
    end
  end
end

module SimpleCov
  module Formatter
    Undercover = ::Undercover::UndercoverSimplecovFormatter
  end
end
