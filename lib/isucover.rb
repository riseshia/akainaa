# frozen_string_literal: true

require 'coverage'

require_relative 'isucover/version'

module Isucover
  class Error < StandardError; end

  class << self
    attr_accessor :project_dir

    def start(project_dir:)
      @project_dir = project_dir
      @project_dir += '/' unless @project_dir.end_with?('/')

      Coverage.start(lines: true)
    end

    def peek_result
      Coverage
        .peek_result
        .select { |k, _v| k.start_with?(project_dir) }
        .transform_keys { |k| k.sub(project_dir, '') }
    end

    def reset
      Coverage.result(stop: false, clear: true)
    end
  end

  class Middleware
    PADDING = 4

    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'] == '/isucover'
        path = extract_path_from_query(env)
        html = render_page(path)

        [200, { 'Content-Type' => 'text/html;charset=utf-8' }, [html]]
      elsif env['PATH_INFO'] == '/isucover/reset'
        path = extract_path_from_query(env)
        Isucover.reset

        [302, { 'Location' => "/isucover?path=#{path}" }, [html]]
      else
        @app.call(env)
      end
    end

    private def extract_path_from_query(env)
      matched = env['QUERY_STRING'].match(/path=([^&]+)/)
      matched ? matched[1] : 'app.rb'
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

    private def render_filelist(files, current_path:)
      li_elements = files.sort.map do |file|
        class_suffix = file == current_path ? ' current' : ''
        <<~HTML
          <li class="pure-menu-item">
            <a href="/isucover?path=#{file}" class="pure-menu-link filepath#{class_suffix}">#{file}</a>
          </li>
        HTML
      end.join

      <<~HTML
        <div>
          <div class="pure-menu">
            <span class="pure-menu-heading">Isucover</span>
            <ul class="pure-menu-list">
              <li class="pure-menu-item">
                <a href="/isucover/reset" class="pure-button pure-button-primary">Reset</a>
              </li>
              <li class="pure-menu-heading">Files</li>
              #{li_elements}
            </ul>
          </div>
        </div>
      HTML
    end

    private def render_page(path)
      result = Isucover.peek_result
      path_result = result[path]

      if path_result.nil?
        return "There is emtpy result for #{path}"
      end

      unless File.exist?(path)
        return "<" + "p>#{path} not found.<" + "/p>"
      end

      filelist = render_filelist(result.keys, current_path: path)

      coverage_on_line = path_result[:lines]
      max_count = coverage_on_line.max_by(&:to_i).to_i + 1

      lines = []
      File.read(path).each_line.with_index do |line, index|
        count = coverage_on_line[index].to_i
        count_top = (count * 10 / max_count).to_i * 10
        line = render_line(index + 1, line, coverage_on_line[index], count_top)

        lines << line
      end

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
              div.count-p10 {
                background-color: #ffffff;
              }
              div.count-p00 {
                background-color: #a3cfbb;
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
