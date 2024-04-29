# frozen_string_literal: true

require "prism"

module Akainaa
  class CallNodeVisitor < Prism::Visitor
    MethodRange = Data.define(:name, :start_line, :end_line) do
      def start_line_as_idx
        start_line - 1
      end

      def method_row_range_as_idx
        (start_line - 1)..(end_line - 1)
      end
    end

    attr_reader :multiline_method_calls

    def initialize
      super

      @multiline_method_calls = []
    end

    def visit_call_node(node)
      if node.arguments &&
         node.message_loc.start_line != node.arguments.location&.end_line

        @multiline_method_calls << MethodRange.new(
          name: node.message,
          start_line: node.message_loc.start_line,
          end_line: node.arguments.location.end_line,
        )
      end

      super
    end
  end
end
