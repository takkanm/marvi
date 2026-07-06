# frozen_string_literal: true

module Marvi
  module Renderer
    class Curses
      # Per-document state for one open file: source markdown, walked lines,
      # scroll position, search state, and file-watch bookkeeping. All layout
      # inputs (content width, page size) are passed in by the renderer so this
      # class stays free of curses calls and can be tested headlessly.
      class Tab
        attr_reader :file, :lines, :markdown, :search_query, :matches, :current_match
        attr_accessor :scroll

        def initialize(file: nil, markdown: nil)
          @file = file
          @markdown = markdown || read_file
          @scroll = 0
          @lines = []
          @walked_width = nil
          clear_search
          mark_reloaded
        end

        def label
          @file ? File.basename(@file) : "(stdin)"
        end

        # Walk lazily: tabs that are not visible keep their lines from the last
        # width they were displayed at and re-walk only when shown again.
        def ensure_walked(width, page_size)
          return if @walked_width == width

          @walked_width = width
          @lines = ASTWalker.new.walk(@markdown, max_width: width)
          clamp_scroll(page_size)
          refresh_search_after_rewalk(page_size)
        end

        def rewalk(width, page_size)
          @walked_width = nil
          ensure_walked(width, page_size)
        end

        def reload(width, page_size)
          @markdown = read_file
          rewalk(width, page_size)
          mark_reloaded
        end

        def max_scroll(page_size)
          [@lines.size - page_size, 0].max
        end

        def clamp_scroll(page_size)
          @scroll = @scroll.clamp(0, max_scroll(page_size))
        end

        def scroll_by(delta, page_size)
          @scroll = (@scroll + delta).clamp(0, max_scroll(page_size))
        end

        def visible_lines(page_size)
          @lines[@scroll, page_size] || []
        end

        def current_source_line(page_size)
          visible_lines(page_size).each { |line| return line.source_line if line.source_line }
          # fall back to searching upward from scroll position
          @scroll.downto(0) { |i| return @lines[i].source_line if @lines[i]&.source_line }
          1
        end

        # --- file watching ---

        # Returns true when the file changed on disk since the last check and
        # the updated flag was newly raised.
        def check_file_updated
          return false unless @file

          mtime = current_mtime
          return false if mtime.nil? || mtime == @last_mtime

          @last_mtime = mtime
          return false if @file_updated

          @file_updated = true
          true
        end

        def file_updated?
          @file_updated
        end

        def mark_reloaded
          @last_mtime = current_mtime
          @file_updated = false
        end

        # --- search ---

        def update_search(query, page_size)
          @search_query = query
          recompute_matches
          focus_match_from(@scroll, page_size) unless @matches.empty?
        end

        def commit_search
          clear_search if @search_query.to_s.empty? || @matches.empty?
        end

        def clear_search
          @search_query = nil
          @matches = []
          @current_match = nil
        end

        def jump_match(direction, page_size)
          return if @matches.empty?

          if @current_match.nil?
            focus_match_from(@scroll, page_size)
          else
            set_current_match(@current_match + direction, page_size)
          end
        end

        def highlight_ranges_for(line_index)
          return nil if @matches.empty?

          ranges = []
          @matches.each_with_index do |(li, start, finish), i|
            ranges << [start, finish, i == @current_match] if li == line_index
          end
          ranges.empty? ? nil : ranges
        end

        def search_hint
          return "  n/N next/prev" if @search_query.nil? || @search_query.empty?
          return "  no matches: #{@search_query}" if @matches.empty?

          position = @current_match ? @current_match + 1 : 0
          "  [#{position}/#{@matches.size}] n/N"
        end

        private

        def read_file
          # Force UTF-8 so markdown parses even under a C/POSIX locale where
          # Encoding.default_external would be US-ASCII.
          @file ? File.read(@file, encoding: Encoding::UTF_8) : ""
        end

        def current_mtime
          return nil unless @file

          File.mtime(@file)
        rescue SystemCallError
          nil
        end

        def refresh_search_after_rewalk(page_size)
          return unless @search_query

          recompute_matches
          focus_match_from(@scroll, page_size) unless @matches.empty?
        end

        def recompute_matches
          @matches = []
          @current_match = nil
          needle = @search_query.to_s.downcase
          return if needle.empty?

          @lines.each_with_index do |line, line_index|
            haystack = line.plain_text.downcase
            next if haystack.empty?

            pos = 0
            while (idx = haystack.index(needle, pos))
              @matches << [line_index, idx, idx + needle.length]
              pos = idx + needle.length
            end
          end
        end

        def focus_match_from(from_line, page_size)
          return if @matches.empty?

          index = @matches.index { |match| match[0] >= from_line } || 0
          set_current_match(index, page_size)
        end

        def set_current_match(index, page_size)
          return if @matches.empty?

          @current_match = index % @matches.size
          ensure_match_visible(@matches[@current_match][0], page_size)
        end

        def ensure_match_visible(line_index, page_size)
          if line_index < @scroll || line_index >= @scroll + page_size
            @scroll = [line_index, max_scroll(page_size)].min
          end
        end
      end
    end
  end
end
