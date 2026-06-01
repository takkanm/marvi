# frozen_string_literal: true

require "curses"
require "shellwords"

module Marvi
  module Renderer
    class Curses
      COLOR_PAIRS = {
        cyan: 1,
        green: 2,
        yellow: 3,
        magenta: 4,
        white: 5,
        cyan_on_dark: 6,
        green_on_dark: 7,
        yellow_on_dark: 8,
        magenta_on_dark: 9,
        white_on_dark: 10
      }.freeze

      ITALIC_ATTR = (defined?(::Curses::A_ITALIC) ? ::Curses::A_ITALIC : 0)

      FILE_POLL_INTERVAL_MS = 500

      CTRL_D = 4
      CTRL_U = 21

      MIN_HORIZONTAL_PADDING = 2
      HORIZONTAL_PADDING_DIVISOR = 12

      def render(markdown, file: nil)
        @file = file
        @markdown = markdown
        @scroll = 0
        mark_reloaded

        init_curses_state
        rewalk
        draw

        catch(:quit) do
          loop do
            key = ::Curses.getch
            if key.nil? || key == -1
              check_file_updated
            else
              handle_key(key)
            end
          end
        end
      ensure
        ::Curses.close_screen
      end

      private

      # ncurses uses the terminfo `rep` capability ("ESC[Nb") to compress runs of
      # identical glyphs, but ghostty mishandles it and drops the run from the
      # screen — table borders and long padding go missing. The bug surfaces both
      # under xterm-ghostty directly and inside multiplexers like cmux that ship a
      # terminfo whose xterm-256color entry advertises `rep`. Detect `rep` in the
      # active terminfo and swap to a known no-rep alternative around initscr only.
      REP_SAFE_TERMS = %w[screen-256color tmux-256color xterm-color xterm].freeze

      def with_safe_term
        original = ENV["TERM"]
        replacement = rep_safe_term_for(original)
        ENV["TERM"] = replacement if replacement
        yield
      ensure
        ENV["TERM"] = original
      end

      def rep_safe_term_for(term)
        return nil if term.nil? || term.empty?
        return nil unless terminfo_has_rep?(term)

        REP_SAFE_TERMS.find { |candidate| candidate != term && terminfo_exists?(candidate) && !terminfo_has_rep?(candidate) }
      end

      def terminfo_has_rep?(term)
        infocmp(term)&.include?("rep=") || false
      end

      def terminfo_exists?(term)
        !infocmp(term).nil?
      end

      def infocmp(term)
        @infocmp_cache ||= {}
        return @infocmp_cache[term] if @infocmp_cache.key?(term)

        output = IO.popen(["infocmp", "-1", term, err: File::NULL], &:read)
        @infocmp_cache[term] = $?.success? ? output : nil
      rescue
        @infocmp_cache[term] = nil
      end

      def setup_colors
        ::Curses.init_pair(COLOR_PAIRS[:cyan], ::Curses::COLOR_CYAN, -1)
        ::Curses.init_pair(COLOR_PAIRS[:green], ::Curses::COLOR_GREEN, -1)
        ::Curses.init_pair(COLOR_PAIRS[:yellow], ::Curses::COLOR_YELLOW, -1)
        ::Curses.init_pair(COLOR_PAIRS[:magenta], ::Curses::COLOR_MAGENTA, -1)
        ::Curses.init_pair(COLOR_PAIRS[:white], ::Curses::COLOR_WHITE, -1)
        ::Curses.init_pair(COLOR_PAIRS[:cyan_on_dark], ::Curses::COLOR_CYAN, ::Curses::COLOR_BLACK)
        ::Curses.init_pair(COLOR_PAIRS[:green_on_dark], ::Curses::COLOR_GREEN, ::Curses::COLOR_BLACK)
        ::Curses.init_pair(COLOR_PAIRS[:yellow_on_dark], ::Curses::COLOR_YELLOW, ::Curses::COLOR_BLACK)
        ::Curses.init_pair(COLOR_PAIRS[:magenta_on_dark], ::Curses::COLOR_MAGENTA, ::Curses::COLOR_BLACK)
        ::Curses.init_pair(COLOR_PAIRS[:white_on_dark], ::Curses::COLOR_WHITE, ::Curses::COLOR_BLACK)
      end

      def handle_key(key)
        case key
        when "q", "Q", 27 then throw :quit
        when "j", ::Curses::Key::DOWN then scroll_by(1)
        when "k", ::Curses::Key::UP then scroll_by(-1)
        when "d", CTRL_D then scroll_by(page_size / 2)
        when "u", CTRL_U then scroll_by(-page_size / 2)
        when "f", " ", ::Curses::Key::NPAGE then scroll_by(page_size)
        when "b", ::Curses::Key::PPAGE then scroll_by(-page_size)
        when "g" then @scroll = 0
                      draw
        when "G" then @scroll = max_scroll
                      draw
        when "e" then launch_editor if @file
        when "r", "R" then reload_from_key if @file
        when ::Curses::Key::RESIZE then handle_resize
        end
      end

      def handle_resize
        rewalk
        @scroll = [@scroll, max_scroll].min
        draw
      end

      def rewalk
        @lines = ASTWalker.new.walk(@markdown, max_width: content_width)
      end

      def horizontal_padding
        cols = ::Curses.cols
        return 0 if cols <= MIN_HORIZONTAL_PADDING * 2
        [MIN_HORIZONTAL_PADDING, cols / HORIZONTAL_PADDING_DIVISOR].max
      end

      def content_width
        [::Curses.cols - horizontal_padding * 2, 1].max
      end

      def reload_from_key
        reload
        mark_reloaded
        draw
      end

      def check_file_updated
        return unless @file
        mtime = current_mtime
        return if mtime.nil? || mtime == @last_mtime

        @last_mtime = mtime
        return if @file_updated

        @file_updated = true
        draw_status_bar
        ::Curses.refresh
      end

      def mark_reloaded
        @last_mtime = current_mtime
        @file_updated = false
      end

      def current_mtime
        return nil unless @file
        File.mtime(@file)
      rescue SystemCallError
        nil
      end

      def launch_editor
        editor = ENV["EDITOR"] || ENV["VISUAL"] || "vi"
        line = current_source_line
        cmd = build_editor_command(editor, @file, line)

        ::Curses.close_screen
        system(cmd)
        init_curses_state
        reload
        mark_reloaded
        draw
      end

      def reload
        @markdown = File.read(@file)
        rewalk
        @scroll = [@scroll, max_scroll].min
      end

      def init_curses_state
        with_safe_term { ::Curses.init_screen }
        ::Curses.start_color
        ::Curses.use_default_colors
        ::Curses.noecho
        ::Curses.cbreak
        ::Curses.stdscr.keypad(true)
        ::Curses.stdscr.timeout = FILE_POLL_INTERVAL_MS
        setup_colors
      end

      def build_editor_command(editor, file, line)
        base = File.basename(editor.split.first)
        escaped = Shellwords.escape(file)
        case base
        when "code"
          "#{editor} --goto #{escaped}:#{line}"
        when "subl", "sublime_text"
          "#{editor} #{escaped}:#{line}"
        else
          # vim, nvim, nano, emacs, micro, etc.
          "#{editor} +#{line} #{escaped}"
        end
      end

      def current_source_line
        visible_lines.each { |line| return line.source_line if line.source_line }
        # fall back to searching upward from scroll position
        @scroll.downto(0) { |i| return @lines[i].source_line if @lines[i]&.source_line }
        1
      end

      def draw
        ::Curses.clear
        padding = horizontal_padding
        visible_lines.each_with_index do |line, row|
          ::Curses.setpos(row, padding)
          render_line(line)
        end
        draw_status_bar
        ::Curses.refresh
      end

      def draw_status_bar
        ::Curses.setpos(::Curses.lines - 1, 0)
        top = @scroll + 1
        bottom = [@scroll + page_size, @lines.size].min
        edit_hint = @file ? "  e edit" : ""
        status = " #{top}-#{bottom}/#{@lines.size}  j/k scroll  g/G top/bottom#{edit_hint}  q quit"
        updated_hint = @file_updated ? "  ● updated (r to reload) " : ""
        available = [::Curses.cols - updated_hint.length, 0].max

        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan])) do
          ::Curses.addstr(status.ljust(available)[0, available])
        end
        unless updated_hint.empty?
          ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:yellow]) | ::Curses::A_BOLD) do
            ::Curses.addstr(updated_hint)
          end
        end
      end

      def render_line(line)
        line.spans.each do |span|
          render_span(span)
        rescue ::Curses::Error
          # ignore write errors at line edge
        end
      end

      def render_span(span)
        attr = build_attr(span)
        if attr != 0
          ::Curses.attron(attr) { ::Curses.addstr(span.text) }
        else
          ::Curses.addstr(span.text)
        end
      end

      def build_attr(span)
        attr = 0
        attr |= ::Curses::A_BOLD if span.bold
        attr |= ITALIC_ATTR if span.italic

        pair_key = if span.bg_color == :dark
          :"#{span.color || :green}_on_dark"
        elsif span.color
          span.color
        end

        attr |= ::Curses.color_pair(COLOR_PAIRS[pair_key]) if pair_key
        attr
      end

      def visible_lines
        @lines[@scroll, page_size] || []
      end

      def page_size
        [::Curses.lines - 1, 1].max
      end

      def max_scroll
        [@lines.size - page_size, 0].max
      end

      def scroll_by(delta)
        @scroll = (@scroll + delta).clamp(0, max_scroll)
        draw
      end
    end
  end
end
