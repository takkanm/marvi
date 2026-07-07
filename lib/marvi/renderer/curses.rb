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
      CTRL_N = 14
      CTRL_P = 16
      CTRL_U = 21
      TAB_KEY = 9

      MIN_HORIZONTAL_PADDING = 2
      HORIZONTAL_PADDING_DIVISOR = 12

      # Blank row between the tab bar and the document. Clicks landing on it
      # are attributed to the tab directly above, giving each tab a taller
      # effective click target than the single character cell.
      TAB_BAR_MARGIN_ROWS = 1

      def render(markdown, file: nil)
        run([Tab.new(file: file, markdown: markdown)])
      end

      def render_files(files)
        run(files.map { |file| Tab.new(file: file) })
      end

      private

      def run(tabs)
        @tabs = tabs
        @current = 0
        @search_input = nil
        @status_message = nil

        init_curses_state
        current_tab.ensure_walked(content_width, page_size)
        draw

        catch(:quit) do
          loop do
            key = ::Curses.getch
            if key.nil? || key == -1
              poll_files
            else
              handle_key(key)
            end
          end
        end
      ensure
        ::Curses.close_screen
      end

      def current_tab
        @tabs[@current]
      end

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
        @status_message = nil
        case key
        when "q", "Q", 27 then throw :quit
        when "j", ::Curses::Key::DOWN then scroll_by(1)
        when "k", ::Curses::Key::UP then scroll_by(-1)
        when "d", CTRL_D then scroll_by(page_size / 2)
        when "u", CTRL_U then scroll_by(-page_size / 2)
        when "f", " ", ::Curses::Key::NPAGE then scroll_by(page_size)
        when "b", ::Curses::Key::PPAGE then scroll_by(-page_size)
        when "g" then current_tab.scroll = 0
                      draw
        when "G" then current_tab.scroll = current_tab.max_scroll(page_size)
                      draw
        when "/" then start_search
        when "n" then jump_match(1)
        when "N" then jump_match(-1)
        when "e" then launch_editor if current_tab.file
        when "r", "R" then reload_from_key if current_tab.file
        when "\t", TAB_KEY then cycle_tab(1)
        when ::Curses::Key::BTAB then cycle_tab(-1)
        when "1".."9" then switch_to(key.to_i - 1)
        when "o" then start_open
        when "x" then close_current_tab
        when ::Curses::Key::MOUSE then handle_mouse
        when ::Curses::Key::RESIZE then handle_resize
        end
      end

      # --- tabs ---

      def cycle_tab(delta)
        return if @tabs.size <= 1

        switch_to((@current + delta) % @tabs.size)
      end

      def switch_to(index)
        return if index.negative? || index >= @tabs.size

        @current = index
        current_tab.ensure_walked(content_width, page_size)
        draw
      end

      def close_current_tab
        throw :quit if @tabs.size == 1

        @tabs.delete_at(@current)
        @current = [@current, @tabs.size - 1].min
        update_mousemask
        # The bar may have lost a row (or disappeared), changing the page size.
        current_tab.ensure_walked(content_width, page_size)
        draw
      end

      def open_tab(path)
        path = File.expand_path(path)
        existing = @tabs.index { |tab| tab.file == path }
        return switch_to(existing) if existing

        unless File.file?(path) && File.readable?(path)
          @status_message = " cannot open: #{path} "
          draw
          return
        end

        @tabs << Tab.new(file: path)
        update_mousemask
        switch_to(@tabs.size - 1)
      end

      def update_mousemask
        return unless ::Curses.respond_to?(:mousemask)

        # Claim the mouse only when the tab bar is shown, so single-document
        # sessions keep native terminal text selection.
        mask = (@tabs.size > 1) ? (::Curses::BUTTON1_CLICKED | ::Curses::BUTTON1_PRESSED) : 0
        ::Curses.mousemask(mask)
      end

      def handle_mouse
        event = ::Curses.getmouse
        return unless event
        return if (event.bstate & (::Curses::BUTTON1_CLICKED | ::Curses::BUTTON1_PRESSED)).zero?

        item = TabBar.item_for_click(tab_layout, event.y, event.x)
        switch_to(item.index) if item
      end

      def tab_layout
        return [] if @tabs.size <= 1

        labels = @tabs.each_with_index.map { |tab, i| tab_label(tab, i) }
        TabBar.layout(labels, ::Curses.cols)
      end

      def tab_label(tab, index)
        updated_mark = tab.file_updated? ? " ●" : ""
        "#{index + 1}:#{tab.label}#{updated_mark}"
      end

      def tab_bar_height
        rows = TabBar.rows(tab_layout)
        rows.zero? ? 0 : rows + TAB_BAR_MARGIN_ROWS
      end

      def draw_tab_bar(layout)
        layout.each do |item|
          ::Curses.setpos(item.row, item.col)
          attr = if item.index == @current
            ::Curses::A_REVERSE | ::Curses::A_BOLD
          else
            ::Curses.color_pair(COLOR_PAIRS[:cyan])
          end
          ::Curses.attron(attr) { ::Curses.addstr(item.text) }
        rescue ::Curses::Error
          # ignore write errors at screen edge
        end
      end

      def handle_resize
        current_tab.rewalk(content_width, page_size)
        draw
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
        current_tab.reload(content_width, page_size)
        draw
      end

      def poll_files
        updated = @tabs.select(&:check_file_updated)
        draw unless updated.empty?
      end

      def launch_editor
        tab = current_tab
        editor = ENV["EDITOR"] || ENV["VISUAL"] || "vi"
        line = tab.current_source_line(page_size)
        cmd = build_editor_command(editor, tab.file, line)

        ::Curses.close_screen
        system(cmd)
        init_curses_state
        tab.reload(content_width, page_size)
        draw
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
        update_mousemask
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

      def draw
        ::Curses.clear
        layout = tab_layout
        draw_tab_bar(layout)
        bar_rows = TabBar.rows(layout)
        offset = bar_rows.zero? ? 0 : bar_rows + TAB_BAR_MARGIN_ROWS
        tab = current_tab
        tab.clamp_scroll(page_size)
        padding = horizontal_padding
        tab.visible_lines(page_size).each_with_index do |line, row|
          ::Curses.setpos(row + offset, padding)
          render_line(line, tab.highlight_ranges_for(tab.scroll + row))
        end
        draw_status_bar
        ::Curses.refresh
      end

      def draw_status_bar
        tab = current_tab
        ::Curses.setpos(::Curses.lines - 1, 0)
        top = tab.scroll + 1
        bottom = [tab.scroll + page_size, tab.lines.size].min
        tab_hint = (@tabs.size > 1) ? " [#{@current + 1}/#{@tabs.size}] Tab next" : ""
        edit_hint = tab.file ? "  e edit" : ""
        status = "#{tab_hint} #{top}-#{bottom}/#{tab.lines.size}  j/k scroll  g/G top/bottom  / search#{tab.search_hint}#{edit_hint}  o open  q quit"
        right_hint = @status_message || (tab.file_updated? ? "  ● updated (r to reload) " : "")
        available = [::Curses.cols - right_hint.length, 0].max

        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan])) do
          ::Curses.addstr(status.ljust(available)[0, available])
        end
        unless right_hint.empty?
          ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:yellow]) | ::Curses::A_BOLD) do
            ::Curses.addstr(right_hint)
          end
        end
      end

      def render_line(line, highlights = nil)
        col = 0
        line.spans.each do |span|
          render_span(span, col, highlights)
          col += span.text.length
        rescue ::Curses::Error
          # ignore write errors at line edge
        end
      end

      def render_span(span, col_offset = 0, highlights = nil)
        attr = build_attr(span)
        if highlights.nil? || highlights.empty?
          write_text(span.text, attr)
          return
        end

        highlight_segments(span.text, col_offset, highlights).each do |text, state|
          seg_attr = attr
          seg_attr |= ::Curses::A_REVERSE if state
          seg_attr |= ::Curses::A_BOLD if state == :current
          write_text(text, seg_attr)
        end
      end

      def write_text(text, attr)
        if attr != 0
          ::Curses.attron(attr) { ::Curses.addstr(text) }
        else
          ::Curses.addstr(text)
        end
      end

      # Split a span's text into runs of identical highlight state so each run can
      # be drawn with the matching attributes. Highlight ranges are expressed in
      # whole-line character offsets, hence col_offset locates this span on the line.
      def highlight_segments(text, col_offset, highlights)
        chars = text.chars
        states = Array.new(chars.length)
        highlights.each do |start, finish, current|
          start.upto(finish - 1) do |c|
            idx = c - col_offset
            next if idx.negative? || idx >= chars.length
            states[idx] = :current if current
            states[idx] ||= true
          end
        end

        segments = []
        chars.each_with_index do |ch, i|
          if segments.empty? || segments.last[1] != states[i]
            segments << [ch.dup, states[i]]
          else
            segments.last[0] << ch
          end
        end
        segments
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

      def page_size
        [::Curses.lines - 1 - tab_bar_height, 1].max
      end

      def scroll_by(delta)
        current_tab.scroll_by(delta, page_size)
        draw
      end

      # --- line-editing prompts (search and open) ---

      BACKSPACE_KEYS = [127, 8].freeze

      def start_search
        @search_input = ""
        update_search(@search_input)
        draw_prompt("/#{@search_input}")

        loop do
          key = ::Curses.getch
          next if key.nil? || key == -1

          case key
          when 27 # ESC cancels and clears the search
            current_tab.clear_search
            @search_input = nil
            draw
            return
          when "\n", "\r", 10, 13, ::Curses::Key::ENTER
            current_tab.commit_search
            @search_input = nil
            draw
            return
          when *BACKSPACE_KEYS, ::Curses::Key::BACKSPACE
            @search_input = @search_input[0...-1] || ""
            update_search(@search_input)
            draw_prompt("/#{@search_input}")
          else
            next unless key.is_a?(String) && key.match?(/\A[[:print:]]\z/)
            @search_input += key
            update_search(@search_input)
            draw_prompt("/#{@search_input}")
          end
        end
      end

      def update_search(query)
        current_tab.update_search(query, page_size)
        draw
      end

      def jump_match(direction)
        current_tab.jump_match(direction, page_size)
        draw
      end

      def start_open
        picker = FilePicker.new
        input = ""
        selected = 0

        loop do
          candidates = picker.candidates(input)
          selected = candidates.empty? ? 0 : selected % candidates.size
          draw_picker(input, candidates, selected)

          key = ::Curses.getch
          next if key.nil? || key == -1

          case key
          when 27 # ESC cancels
            draw
            return
          when "\n", "\r", 10, 13, ::Curses::Key::ENTER
            choice = candidates[selected] || input.strip
            if choice.empty?
              draw
              return
            elsif choice.end_with?("/")
              # descend into the selected directory and keep picking
              input = choice
              selected = 0
            else
              open_tab(choice)
              return
            end
          when "\t", TAB_KEY
            if picker.path_mode?(input)
              input = picker.complete(input)
            else
              selected += 1
            end
          when ::Curses::Key::BTAB
            selected -= 1
          when CTRL_N, ::Curses::Key::DOWN
            selected += 1
          when CTRL_P, ::Curses::Key::UP
            selected -= 1
          when *BACKSPACE_KEYS, ::Curses::Key::BACKSPACE
            input = input[0...-1] || ""
            selected = 0
          else
            if key.is_a?(String) && key.match?(/\A[[:print:]]\z/)
              input += key
              selected = 0
            end
          end
        end
      end

      def draw_picker(input, candidates, selected)
        ::Curses.clear
        width = ::Curses.cols
        position = candidates.empty? ? 0 : selected + 1
        header = " open file  (#{position}/#{candidates.size})  C-n/C-p select  Enter open  ESC cancel"
        ::Curses.setpos(0, 0)
        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan]) | ::Curses::A_BOLD) do
          ::Curses.addstr(header.ljust(width)[0, width])
        end

        list_rows = [::Curses.lines - 2, 1].max
        offset = (selected < list_rows) ? 0 : selected - list_rows + 1
        (candidates[offset, list_rows] || []).each_with_index do |candidate, i|
          ::Curses.setpos(1 + i, 0)
          text = " #{candidate} ".ljust(width)[0, width]
          if offset + i == selected
            ::Curses.attron(::Curses::A_REVERSE) { ::Curses.addstr(text) }
          else
            ::Curses.addstr(text)
          end
        rescue ::Curses::Error
          # ignore write errors at screen edge
        end

        prompt = "open: #{input}"
        ::Curses.setpos(::Curses.lines - 1, 0)
        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan])) do
          ::Curses.addstr(prompt.ljust(width)[0, width])
        end
        ::Curses.setpos(::Curses.lines - 1, [prompt.length, width - 1].min)
        ::Curses.refresh
      end

      def draw_prompt(prompt)
        ::Curses.setpos(::Curses.lines - 1, 0)
        ::Curses.attron(::Curses.color_pair(COLOR_PAIRS[:cyan])) do
          ::Curses.addstr(prompt.ljust(::Curses.cols)[0, ::Curses.cols])
        end
        ::Curses.setpos(::Curses.lines - 1, [prompt.length, ::Curses.cols - 1].min)
        ::Curses.refresh
      end
    end
  end
end

require_relative "curses/tab"
require_relative "curses/tab_bar"
require_relative "curses/file_picker"
