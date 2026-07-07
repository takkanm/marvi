# frozen_string_literal: true

require "unicode/display_width"

module Marvi
  module Renderer
    class Curses
      # Pure layout computation for the tab bar so it can be tested without a
      # terminal. Tabs are packed greedily left to right and wrap to a new row
      # when the screen width is exceeded, producing a multi-row bar.
      module TabBar
        Item = Struct.new(:index, :text, :row, :col, :width, keyword_init: true) do
          def contains?(y, x)
            y == row && x >= col && x < col + width
          end
        end

        module_function

        def layout(labels, screen_width)
          screen_width = [screen_width, 1].max
          row = 0
          col = 0
          labels.each_with_index.map do |label, index|
            text = truncate_to_width(" #{label} ", screen_width)
            width = Unicode::DisplayWidth.of(text)
            if col.positive? && col + width > screen_width
              row += 1
              col = 0
            end
            item = Item.new(index: index, text: text, row: row, col: col, width: width)
            col += width
            item
          end
        end

        def rows(items)
          items.empty? ? 0 : items.last.row + 1
        end

        def item_at(items, y, x)
          items.find { |item| item.contains?(y, x) }
        end

        # Resolve a click including the margin row directly below the bar,
        # which is attributed to the tab above it — a taller click target.
        def item_for_click(items, y, x)
          item_at(items, y, x) || ((y == rows(items)) ? item_at(items, y - 1, x) : nil)
        end

        def truncate_to_width(text, max_width)
          return text if Unicode::DisplayWidth.of(text) <= max_width

          result = +""
          width = 0
          text.each_char do |ch|
            ch_width = Unicode::DisplayWidth.of(ch)
            break if width + ch_width > max_width

            result << ch
            width += ch_width
          end
          result
        end
      end
    end
  end
end
