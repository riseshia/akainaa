# frozen_string_literal: true

require 'coverage'
require 'fileutils'

require_relative 'akainaa/version'
require_relative 'akainaa/call_node_visitor'
require_relative 'akainaa/util'

module Akainaa
  class Error < StandardError; end

  class << self
    attr_accessor :project_dir, :ignore_files, :hide_not_executed_files

    def start(
      project_dir:,
      ignore_glob_patterns: [],
      hide_not_executed_files: false,
      online_emit: nil
    )
      @project_dir = project_dir
      @project_dir += '/' unless @project_dir.end_with?('/')
      ignore_files = ignore_glob_patterns.flat_map do |pattern|
        Dir["#{@project_dir}#{pattern}"].to_a
      end
      @ignore_files = Set.new(ignore_files)
      @hide_not_executed_files = hide_not_executed_files
      @monitor = Monitor.new
      @first_emitted = false

      Coverage.start(lines: true)

      if online_emit.is_a?(Hash)
        option = default_online_emit.merge(online_emit)
        FileUtils.mkdir_p(File.dirname(option[:path]))
        start_multipart_emit(option)

        if option[:trap_at_exit]
          at_exit do
            write_result(peek_result, option[:path])
          end
        end
      end
    end

    def peek_result
      Coverage
        .peek_result
        .select { |k, _v| k.start_with?(project_dir) }
        .reject { |k, _v| ignore_files.member?(k) }
        .transform_keys { |k| k.sub(project_dir, '') }
    end

    def reset
      @monitor.synchronize do
        Coverage.result(stop: false, clear: true)
        @previous_result = {}
      end
    end

    private def write_result(result, path)
      unless @first_emitted
        result['clear'] = true
      end
      File.write(path, result.to_json)
      @first_emitted = true
    end

    private def default_online_emit
      {
        mode: :file,
        interval: 1,
        path: 'tmp/coverage.json',
        trap_at_exit: true,
      }
    end

    private def start_multipart_emit(option)
      Thread.new do
        @monitor.synchronize do
          @previous_result = {}
        end

        loop do
          sleep option[:interval]
          current_result = peek_result

          diff = {}
          current_result.each do |path, path_coverage|
            previous_path_coverage = @previous_result[path]

            if previous_path_coverage.nil?
              diff[path] = path_coverage
            elsif previous_path_coverage[:lines].size != path_coverage[:lines].size
              diff[path] = path_coverage
            else
              diff[path] = { lines: [] }

              path_coverage[:lines].each_with_index do |count, index|
                val = count ? count - previous_path_coverage[:lines][index] : nil

                diff[path][:lines] << val
              end
            end
          end

          @monitor.synchronize do
            @previous_result = current_result
          end

          write_result(diff, option[:path])
        end
      end
    end
  end

  class Middleware
    PADDING = 4

    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'] == '/akainaa'
        path = extract_path_from_query(env)
        html = render_page(path)

        [200, { 'Content-Type' => 'text/html;charset=utf-8' }, [html]]
      elsif env['PATH_INFO'] == '/akainaa/reset'
        path = extract_path_from_query(env)
        Akainaa.reset

        [302, { 'Location' => "/akainaa?path=#{path}" }, []]
      else
        @app.call(env)
      end
    end

    private def extract_path_from_query(env)
      matched = env['QUERY_STRING'].match(/path=([^&]+)/)
      matched ? matched[1] : nil
    end

    private def render_line(lineno, code, count, count_top)
      <<~HTML
        <div class="line pure-g count-p#{count_top}">
          <div class="executed-count pure-u-2-24">
            <p>#{count}</p>
          </div>
          <div class="lineno pure-u-2-24">
            <p>#{lineno}:</p>
          </div>
          <div class="code pure-u-20-24">
            <pre class="code language-ruby">#{code}</pre>
            </code>
          </div>
        </div>
      HTML
    end

    private def render_filelist(coverage_result, summary:, current_path:)
      files = coverage_result.keys
      max_count_on_proj = summary.max_count_on_proj
      max_count_width = max_count_on_proj.to_s.size

      li_elements = files.sort.map do |file|
        total_count_on_file = coverage_result[file][:lines].reject(&:nil?).sum
        next '' if Akainaa.hide_not_executed_files && total_count_on_file == 0

        count_top = (total_count_on_file * 10 / max_count_on_proj).to_i * 10

        class_suffix = file == current_path ? ' current' : ''
        <<~HTML
          <li class="pure-menu-item">
          <a href="/akainaa?path=#{file}" class="pure-menu-link filepath#{class_suffix} count-p#{count_top}"">(#{total_count_on_file.to_s.rjust(max_count_width)}) #{file}</a>
          </li>
        HTML
      end.join

      <<~HTML
        <div>
          <div class="pure-menu">
            <span class="pure-menu-heading">赤いなぁ</span>
            <ul class="pure-menu-list">
              <li class="pure-menu-item">
                <a href="/akainaa/reset" class="pure-button pure-button-primary">Reset</a>
              </li>
              <li class="pure-menu-heading">Files</li>
              #{li_elements}
            </ul>
          </div>
        </div>
      HTML
    end

    CoverageSummary = Data.define(:file_path_has_max_count, :max_count_on_proj)

    private def generate_summary(coverage_result)
      file_path_has_max_count = coverage_result.max_by { |_, cv| cv[:lines].reject(&:nil?).sum }.first
      max_count_on_proj = coverage_result
        .values
        .map { |cv| cv[:lines].reject(&:nil?).sum }
        .max + 1

      CoverageSummary.new(file_path_has_max_count:, max_count_on_proj:)
    end

    private def render_page(path)
      result = Akainaa.peek_result

      summary = generate_summary(result)

      path = summary.file_path_has_max_count if path.nil?

      path_result = result[path]

      if path_result.nil?
        return "There is emtpy result for #{path}"
      end

      unless File.exist?(path)
        return "<" + "p>#{path} not found.<" + "/p>"
      end

      coverage_on_line = Akainaa::Util.fullfill_multiline_method_calls(path, path_result[:lines])
      max_count_on_file = coverage_on_line.reject(&:nil?).max + 1

      lines = []
      File.read(path).each_line.with_index do |line, index|
        count = coverage_on_line[index].to_i
        count_top = (count * 10 / max_count_on_file).to_i * 10
        line = render_line(index + 1, line, coverage_on_line[index], count_top)

        lines << line
      end

      filelist = render_filelist(result, summary:, current_path: path)

      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/purecss@3.0.0/build/pure-min.css" integrity="sha384-X38yfunGUhNzHpBaEBsWLO+A0HDYOQi8ufWDkZ0k9e0eXz/tH3II7uKZ9msv++Ls" crossorigin="anonymous">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css">
            <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/11.4.0/styles/a11y-light.min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/ruby.min.js"></script>
            <style>
              .sidebar {
                background-color: #eee;
              }

              .pure-menu-heading {
                font-weight: bold;
              }

              .line {
                line-height: 20px;
              }

              .executed-count, .lineno {
                text-align: right;
              }

              p {
                padding: 0 5 0 5;
                margin: 0px;
              }

              pre.code {
                margin: 0px;
                background: transparent;
              }

              a.filepath {
                text-wrap: balance;
                word-break: break-all;
                color: #000;
              }
              a.filepath.current {
                font-weight: bold;
              }

              div.count-p90 {
                background-color: #ff392e;
              }
              div.count-p90:hover {
                background-color: #fedcda;
              }
              div.count-p80 {
                background-color: #ff5047;
              }
              div.count-p80:hover {
                background-color: #fedcda;
              }
              div.count-p70 {
                background-color: #ff675f;
              }
              div.count-p70:hover {
                background-color: #fedcda;
              }
              div.count-p60 {
                background-color: #ff7f78;
              }
              div.count-p50 {
                background-color: #ff9690;
              }
              div.count-p40 {
                background-color: #ffada9;
              }
              div.count-p30 {
                background-color: #fec4c1;
              }
              div.count-p20 {
                background-color: #fedcda;
              }
              div.count-p10, div.count-p0 {
                background-color: #ffffff;
              }
              .pure-menu-item > a.count-p90 {
                background-color: #ff392e;
              }
              .pure-menu-item > a.count-p80 {
                background-color: #ff5047;
              }
              .pure-menu-item > a.count-p70 {
                background-color: #ff675f;
              }
              .pure-menu-item > a.count-p60 {
                background-color: #ff7f78;
              }
              .pure-menu-item > a.count-p50 {
                background-color: #ff9690;
              }
              .pure-menu-item > a.count-p40 {
                background-color: #ffada9;
              }
              .pure-menu-item > a.count-p30 {
                background-color: #ffffff;
              }
              .pure-menu-item > a.count-p20 {
                background-color: #ffffff;
              }
              .pure-menu-item > a.count-p10 {
                background-color: #ffffff;
              }
              .pure-menu-item > a.count-p0 {
                background-color: #ffffff;
              }
            </style>
          </head>
          <body>
            <div id="layout" class="pure-g">
              <div class="sidebar pure-u-1-4">
                #{filelist}
              </div>
              <div class="content pure-u-3-4">
                #{lines.join("\n")}
              </div>
            </div>
            <script>
              document.querySelectorAll('pre.code').forEach(el => {
                hljs.highlightElement(el);
              });
            </script>
          </body>
        </html>
      HTML
    end
  end
end
