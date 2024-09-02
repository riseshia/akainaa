# frozen_string_literal: true

module Akainaa
  module Util
    module_function

    # @param [String] source_path
    # @param [Array<Integer>] lines
    #
    # @return [Array<Integer>]
    def fullfill_multiline_method_calls(source_path, lines)
      result = Prism.parse_file(source_path)
      prog_node = result.value

      visitor = ::Akainaa::CallNodeVisitor.new
      visitor.visit(prog_node)

      fullfilled_lines = lines.dup

      visitor.multiline_method_calls.each do |method_range|
        call_count = lines[method_range.start_line_as_idx]
        next if call_count.nil?

        method_range.method_row_range_as_idx.each do |idx|
          if fullfilled_lines[idx].nil?
            fullfilled_lines[idx] = call_count
          elsif fullfilled_lines[idx] < call_count
            fullfilled_lines[idx] = call_count
          else
            # use as it is
          end
        end
      end

      fullfilled_lines
    end
  end
end
