# frozen_string_literal: true

require "kramdown"
require "kramdown-parser-gfm"
require "unicode/display_width"

module Marvi
  class ASTWalker
    HEADER_COLORS = %i[cyan green yellow magenta white white].freeze

    DEFAULT_MAX_WIDTH = 80
    MIN_COL_WIDTH = 4

    def walk(markdown, max_width: nil)
      @max_width = max_width || Integer(ENV["COLUMNS"] || DEFAULT_MAX_WIDTH)
      doc = Kramdown::Document.new(markdown, input: "GFM")
      lines = render_block(doc.root)
      lines.pop while lines.last&.plain_text&.empty?
      lines
    end

    private

    def render_block(el, indent: 0, list_type: nil, list_index: nil)
      case el.type
      when :root
        el.children.flat_map { |child| render_block(child) }
      when :header
        render_header(el)
      when :p
        src = el.options[:location]
        wrapped = wrap_spans(render_inline_children(el), @max_width)
        wrapped.each_with_index.map { |spans, i| RichLine.new(spans, source_line: (i.zero? ? src : nil)) } + [RichLine.blank]
      when :ul
        el.children.flat_map { |child| render_block(child, indent: indent, list_type: :ul) } + [RichLine.blank]
      when :ol
        el.children.each_with_index.flat_map do |child, i|
          render_block(child, indent: indent, list_type: :ol, list_index: i + 1)
        end + [RichLine.blank]
      when :li
        render_li(el, indent: indent, list_type: list_type, list_index: list_index)
      when :codeblock
        render_codeblock(el)
      when :blockquote
        render_blockquote(el)
      when :hr
        src = el.options[:location]
        [RichLine.new([Span.new(text: "─" * 60, color: :cyan)], source_line: src), RichLine.blank]
      when :table
        render_table(el)
      when :blank
        [RichLine.blank]
      else
        el.children.flat_map { |child| render_block(child) }
      end
    end

    def render_header(el)
      level = el.options[:level]
      color = HEADER_COLORS[level - 1]
      src = el.options[:location]
      prefix = Span.new(text: "#" * level + " ", bold: true, color: color)
      content = render_inline_children(el).map do |s|
        Span.new(text: s.text, bold: true, italic: s.italic, color: s.color || color, bg_color: s.bg_color)
      end
      wrap_with_prefix([prefix], content, @max_width, source_line: src) + [RichLine.blank]
    end

    def render_li(el, indent:, list_type:, list_index:)
      bullet = (list_type == :ol) ? "#{list_index}." : "•"
      prefix = Span.new(text: "#{"  " * indent}#{bullet} ", color: :cyan)
      prefix_width = spans_display_width([prefix])
      hanging = Span.new(text: " " * prefix_width)
      inner_width = [@max_width - prefix_width, MIN_COL_WIDTH].max
      src = el.options[:location]
      lines = []

      el.children.each do |child|
        case child.type
        when :ul, :ol
          nested = render_block(child, indent: indent + 1, list_type: child.type)
          nested.pop while nested.last&.plain_text&.empty?
          lines += nested
        when :p
          content_spans = render_inline_children(child)
          if lines.empty?
            lines += wrap_with_prefix([prefix], content_spans, @max_width, source_line: src)
          else
            child_src = child.options[:location]
            wrapped = wrap_spans(content_spans, inner_width)
            wrapped.each_with_index do |spans, i|
              lines << RichLine.new([hanging] + spans, source_line: (i.zero? ? child_src : nil))
            end
            lines << RichLine.blank
          end
        else
          content_spans = render_inline(child)
          if lines.empty?
            lines += wrap_with_prefix([prefix], content_spans, @max_width, source_line: src)
          else
            wrap_spans(content_spans, inner_width).each do |spans|
              lines << RichLine.new([hanging] + spans)
            end
          end
        end
      end
      lines
    end

    def render_codeblock(el)
      src = el.options[:location]
      lang = el.options[:lang]
      lines = []
      lines << RichLine.new([Span.new(text: lang, color: :yellow)], source_line: src) if lang
      el.value.chomp.split("\n").each_with_index do |line, i|
        line_src = if src
          src + i + (lang ? 1 : 0)
        end
        lines << RichLine.new([Span.new(text: "  #{line}", color: :green, bg_color: :dark)], source_line: line_src)
      end
      lines << RichLine.blank
      lines
    end

    def render_blockquote(el)
      prefix = Span.new(text: "│ ", color: :cyan)
      prefix_width = spans_display_width([prefix])
      # Reduce @max_width while rendering inner content so the │ prefix fits within @max_width
      # without forcing a second wrap pass on already-wrapped lines.
      saved_width = @max_width
      @max_width = [saved_width - prefix_width, MIN_COL_WIDTH].max
      inner = el.children.flat_map { |child| render_block(child) }
      @max_width = saved_width
      inner.map { |line| RichLine.new([prefix] + line.spans, source_line: line.source_line) } + [RichLine.blank]
    end

    def render_table(el)
      src = el.options[:location]
      rows = el.children.flat_map(&:children)
      header_row = el.children.find { |s| s.type == :thead }&.children&.first

      cell_spans = rows.map { |row| row.children.map { |cell| render_inline_children(cell) } }
      natural_widths = cell_spans.map { |row| row.map { |spans| spans_display_width(spans) } }
        .transpose.map { |col| col.max }
      col_widths = shrink_col_widths(natural_widths, @max_width)

      lines = []
      top = col_widths.map { |w| "─" * (w + 2) }.join("┬")
      lines << RichLine.new([Span.new(text: "┌#{top}┐", color: :cyan)], source_line: src)

      rows.each_with_index do |row, ri|
        is_header = row == header_row
        wrapped = row.children.each_with_index.map do |_cell, ci|
          content = cell_spans[ri][ci]
          styled = is_header ? content.map { |s| Span.new(text: s.text, bold: true, italic: s.italic, color: :cyan, bg_color: s.bg_color) } : content
          wrap_spans(styled, col_widths[ci])
        end
        sub_row_count = wrapped.map(&:size).max
        sub_row_count.times do |j|
          row_spans = []
          wrapped.each_with_index do |cell_lines, ci|
            sub_spans = cell_lines[j] || []
            sub_len = spans_display_width(sub_spans)
            padding = col_widths[ci] - sub_len
            row_spans += [Span.new(text: "│ ", color: :cyan)] + sub_spans + [Span.new(text: " " * (padding + 1))]
          end
          row_spans << Span.new(text: "│", color: :cyan)
          lines << RichLine.new(row_spans)
        end

        if is_header
          sep = col_widths.map { |w| "─" * (w + 2) }.join("┼")
          lines << RichLine.new([Span.new(text: "├#{sep}┤", color: :cyan)])
        end
      end

      bottom = col_widths.map { |w| "─" * (w + 2) }.join("┴")
      lines << RichLine.new([Span.new(text: "└#{bottom}┘", color: :cyan)])
      lines << RichLine.blank
      lines
    end

    def shrink_col_widths(widths, max_width)
      budget = max_width - (3 * widths.size + 1)
      total = widths.sum
      return widths if total <= budget

      shrunk = widths.dup
      while total > budget
        max_w, i = shrunk.each_with_index.max_by { |w, _| w }
        break if max_w <= MIN_COL_WIDTH
        shrunk[i] -= 1
        total -= 1
      end
      shrunk
    end

    def wrap_with_prefix(prefix_spans, content_spans, max_width, source_line: nil)
      prefix_width = spans_display_width(prefix_spans)
      inner_width = [max_width - prefix_width, MIN_COL_WIDTH].max
      wrapped = wrap_spans(content_spans, inner_width)
      indent = Span.new(text: " " * prefix_width)
      wrapped.each_with_index.map do |spans, i|
        line_prefix = i.zero? ? prefix_spans : [indent]
        RichLine.new(line_prefix + spans, source_line: (i.zero? ? source_line : nil))
      end
    end

    def wrap_spans(spans, width)
      lines = [[]]
      current_width = 0
      spans.each do |span|
        text = span.text.dup
        until text.empty?
          remaining = width - current_width
          if remaining <= 0
            lines << []
            current_width = 0
            remaining = width
          end
          taken = 0
          chunk_width = 0
          text.each_char do |c|
            cw = Unicode::DisplayWidth.of(c)
            break if chunk_width + cw > remaining
            chunk_width += cw
            taken += c.bytesize
          end
          if taken.zero?
            first_char = text.each_char.first
            taken = first_char.bytesize
            chunk_width = Unicode::DisplayWidth.of(first_char)
          end
          chunk = text.byteslice(0, taken)
          text = text.byteslice(taken..) || ""
          lines.last << Span.new(text: chunk, bold: span.bold, italic: span.italic, color: span.color, bg_color: span.bg_color)
          current_width += chunk_width
          unless text.empty?
            lines << []
            current_width = 0
          end
        end
      end
      lines
    end

    def spans_display_width(spans)
      spans.sum { |s| Unicode::DisplayWidth.of(s.text) }
    end

    def render_inline_children(el)
      el.children.flat_map { |child| render_inline(child) }
    end

    def render_inline(el)
      case el.type
      when :text
        [Span.new(text: el.value)]
      when :strong
        render_inline_children(el).map { |s| Span.new(text: s.text, bold: true, italic: s.italic, color: s.color, bg_color: s.bg_color) }
      when :em
        render_inline_children(el).map { |s| Span.new(text: s.text, bold: s.bold, italic: true, color: s.color, bg_color: s.bg_color) }
      when :codespan
        [Span.new(text: " #{el.value} ", color: :cyan, bg_color: :dark)]
      when :br
        [Span.new(text: "\n")]
      when :smart_quote
        char = {lsquo: "'", rsquo: "'", ldquo: "\u201C", rdquo: "\u201D"}.fetch(el.value, "'")
        [Span.new(text: char)]
      when :entity
        [Span.new(text: el.options[:original] || el.value.char)]
      else
        render_inline_children(el)
      end
    end
  end
end
