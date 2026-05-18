# frozen_string_literal: true

require "io/console"

module Marvi
  module Renderer
    class ANSI
      COLOR_MAP = {
        cyan: Marvi::ANSI::CYAN,
        green: Marvi::ANSI::GREEN,
        yellow: Marvi::ANSI::YELLOW,
        magenta: Marvi::ANSI::MAGENTA,
        white: Marvi::ANSI::WHITE
      }.freeze

      def render(markdown)
        lines = ASTWalker.new.walk(markdown, max_width: terminal_width)
        lines.map { |line| render_line(line) }.join("\n") + "\n"
      end

      private

      def terminal_width
        IO.console&.winsize&.last || Integer(ENV["COLUMNS"] || ASTWalker::DEFAULT_MAX_WIDTH)
      rescue
        ASTWalker::DEFAULT_MAX_WIDTH
      end

      def render_line(line)
        line.spans.map { |span| render_span(span) }.join
      end

      def render_span(span)
        codes = []
        codes << Marvi::ANSI::BOLD if span.bold
        codes << Marvi::ANSI::ITALIC if span.italic
        codes << COLOR_MAP[span.color] if span.color
        codes << Marvi::ANSI::BG_DARK if span.bg_color == :dark
        return span.text if codes.empty?
        "#{codes.join}#{span.text}#{Marvi::ANSI::RESET}"
      end
    end
  end
end
