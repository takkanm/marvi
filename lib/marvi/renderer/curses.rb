# frozen_string_literal: true

require "curses"
require "shellwords"

module Marvi
  module Renderer
    class Curses
      COLOR_PAIRS = {
        cyan:          1,
        green:         2,
        yellow:        3,
        magenta:       4,
        white:         5,
        green_on_dark: 6,
        cyan_on_dark:  7
      }.freeze

      ITALIC_ATTR = (defined?(::Curses::A_ITALIC) ? ::Curses::A_ITALIC : 0)

      def render(markdown, file: nil)
        @file     = file
        @markdown = markdown
        @lines    = ASTWalker.new.walk(markdown)
        @scroll   = 0

        ::Curses.init_screen
        ::Curses.start_color
        ::Curses.use_default_colors
        ::Curses.noecho
        ::Curses.cbreak
        ::Curses.stdscr.keypad(true)
        setup_colors
        draw

        catch(:quit) do
          loop { handle_key(::Curses.getch) }
        end
      ensure
        ::Curses.close_screen
      end

      private

      def setup_colors
        ::Curses.init_pair(COLOR_PAIRS[:cyan],          ::Curses::COLOR_CYAN,    -1)
        ::Curses.init_pair(COLOR_PAIRS[:green],         ::Curses::COLOR_GREEN,   -1)
        ::Curses.init_pair(COLOR_PAIRS[:yellow],        ::Curses::COLOR_YELLOW,  -1)
        ::Curses.init_pair(COLOR_PAIRS[:magenta],       ::Curses::COLOR_MAGENTA, -1)
        ::Curses.init_pair(COLOR_PAIRS[:white],         ::Curses::COLOR_WHITE,   -1)
        ::Curses.init_pair(COLOR_PAIRS[:green_on_dark], ::Curses::COLOR_GREEN,   ::Curses::COLOR_BLACK)
        ::Curses.init_pair(COLOR_PAIRS[:cyan_on_dark],  ::Curses::COLOR_CYAN,    ::Curses::COLOR_BLACK)
      end

      def handle_key(key)
        case key
        when "q", "Q", 27                   then throw :quit
        when "j", ::Curses::Key::DOWN       then scroll_by(1)
        when "k", ::Curses::Key::UP         then scroll_by(-1)
        when "d"                            then scroll_by(page_size / 2)
        when "u"                            then scroll_by(-page_size / 2)
        when "f", " ", ::Curses::Key::NPAGE then scroll_by(page_size)
        when "b", ::Curses::Key::PPAGE      then scroll_by(-page_size)
        when "g"                            then @scroll = 0; draw
        when "G"                            then @scroll = max_scroll; draw
        when "e"                            then launch_editor if @file
        end
      end

      def launch_editor
        editor = ENV["EDITOR"] || ENV["VISUAL"] || "vi"
        line   = current_source_line
        cmd    = build_editor_command(editor, @file, line)

        ::Curses.close_screen
        system(cmd)
        reload
        reinit_curses
        draw
      end

      def reload
        @markdown = File.read(@file)
        @lines    = ASTWalker.new.walk(@markdown)
        @scroll   = [@scroll, max_scroll].min
      end

      def reinit_curses
        ::Curses.init_screen
        ::Curses.start_color
        ::Curses.use_default_colors
        ::Curses.noecho
        ::Curses.cbreak
        ::Curses.stdscr.keypad(true)
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
        visible_lines.each_with_index do |line, row|
          ::Curses.setpos(row, 0)
          render_line(line)
        end
        draw_status_bar
        ::Curses.refresh
      end

      def draw_status_bar
        ::Curses.setpos(::Curses.lines - 1, 0)
        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan])) do
          top    = @scroll + 1
          bottom = [@scroll + page_size, @lines.size].min
          edit_hint = @file ? "  e edit" : ""
          status = " #{top}-#{bottom}/#{@lines.size}  j/k scroll  g/G top/bottom#{edit_hint}  q quit"
          ::Curses.addstr(status.ljust(::Curses.cols)[0, ::Curses.cols])
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
        attr |= ITALIC_ATTR      if span.italic

        pair_key = if span.bg_color == :dark
          span.color == :cyan ? :cyan_on_dark : :green_on_dark
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
        @scroll = [[@scroll + delta, 0].max, max_scroll].min
        draw
      end
    end
  end
end
