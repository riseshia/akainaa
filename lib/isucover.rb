# frozen_string_literal: true

require "coverage"

require_relative "isucover/version"

module Isucover
  class Error < StandardError; end

  class << self
    def start
      Coverage.start(lines: true)
    end

    def peek_result
      Coverage.peek_result
    end
  end

  class Middleware
    PADDING = 4

    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'] == '/isucover'
        matched = env['QUERY_STRING'].match(/path=([^&]+)/)
        path = matched ? matched[1] : 'app.rb'

        if !path.start_with?('/')
          path = "#{Dir.pwd}/#{path}"
        end

        result = Isucover.peek_result[path]
        html = render_result(path, result)
        [200, { 'Content-Type' => 'text/html;charset=utf-8' }, [html]]
      else
        @app.call(env)
      end
    end

    private def render_result(path, result)
      if result.nil?
        return "There is emtpy result for #{path}"
      end

      unless File.exist?(path)
        return "<" + "p>#{path} not found.<" + "/p>"
      end

      coverage_on_line = result[:lines]

      meta_infos = []
      codes = []
      File.read(path).each_line.with_index do |line, index|
        prefix = coverage_on_line[index].to_s.rjust(PADDING)
        lineno = (index + 1).to_s.rjust(PADDING)

        meta_infos << "#{prefix} #{lineno}:"
        codes << line
      end

      <<~HTML
      <html>
      <head>
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css">
      <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/ruby.min.js"></script>
      <style>
      </style>
      </head>
      <body>
      <table>
      <tr>
      <td>
      <pre>#{meta_infos.join("\n")}</pre>
      </td>
      <td>
      <pre><code class="language-ruby">#{codes.join}</code></pre>
      </td>
      </tr>
      </table>

      <script>hljs.highlightAll();</script>
      </body>
      </html>
      HTML
    end
  end
end
