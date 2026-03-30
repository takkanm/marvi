# frozen_string_literal: true

require "kramdown"
require "kramdown-parser-gfm"

module Marvi
  class ASTWalker
    HEADER_COLORS = %i[cyan green yellow magenta white white].freeze

    def walk(markdown)
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
        [RichLine.new(render_inline_children(el)), RichLine.blank]
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
        [RichLine.new([Span.new(text: "─" * 60, color: :cyan)]), RichLine.blank]
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
      prefix = Span.new(text: "#" * level + " ", bold: true, color: color)
      content = render_inline_children(el).map do |s|
        Span.new(text: s.text, bold: true, italic: s.italic, color: s.color || color, bg_color: s.bg_color)
      end
      [RichLine.new([prefix] + content), RichLine.blank]
    end

    def render_li(el, indent:, list_type:, list_index:)
      bullet = list_type == :ol ? "#{list_index}." : "•"
      prefix = Span.new(text: "#{"  " * indent}#{bullet} ", color: :cyan)
      lines = []

      el.children.each do |child|
        case child.type
        when :ul, :ol
          nested = render_block(child, indent: indent + 1, list_type: child.type)
          nested.pop while nested.last&.plain_text&.empty?
          lines += nested
        when :p
          if lines.empty?
            lines << RichLine.new([prefix] + render_inline_children(child))
          else
            lines += render_block(child)
          end
        else
          if lines.empty?
            lines << RichLine.new([prefix] + render_inline(child))
          else
            lines << RichLine.new(render_inline(child))
          end
        end
      end
      lines
    end

    def render_codeblock(el)
      lang = el.options[:lang]
      lines = []
      lines << RichLine.new([Span.new(text: lang, color: :yellow)]) if lang
      el.value.chomp.split("\n").each do |line|
        lines << RichLine.new([Span.new(text: "  #{line}", color: :green, bg_color: :dark)])
      end
      lines << RichLine.blank
      lines
    end

    def render_blockquote(el)
      inner = el.children.flat_map { |child| render_block(child) }
      prefix = Span.new(text: "│ ", color: :cyan)
      inner.map { |line| RichLine.new([prefix] + line.spans) } + [RichLine.blank]
    end

    def render_table(el)
      rows = el.children.flat_map(&:children)
      header_row = el.children.find { |s| s.type == :thead }&.children&.first

      cell_spans = rows.map { |row| row.children.map { |cell| render_inline_children(cell) } }
      col_widths = cell_spans.map { |row| row.map { |spans| spans.sum { |s| s.text.length } } }
        .transpose.map { |col| col.max }

      lines = []
      top = col_widths.map { |w| "─" * (w + 2) }.join("┬")
      lines << RichLine.new([Span.new(text: "┌#{top}┐", color: :cyan)])

      rows.each_with_index do |row, ri|
        is_header = row == header_row
        row_spans = []
        row.children.each_with_index do |cell, ci|
          content = cell_spans[ri][ci]
          plain_len = content.sum { |s| s.text.length }
          padding = col_widths[ci] - plain_len
          styled = is_header ? content.map { |s| Span.new(text: s.text, bold: true, color: :cyan) } : content
          row_spans += [Span.new(text: "│ ", color: :cyan)] + styled + [Span.new(text: " " * (padding + 1))]
        end
        row_spans << Span.new(text: "│", color: :cyan)
        lines << RichLine.new(row_spans)

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
