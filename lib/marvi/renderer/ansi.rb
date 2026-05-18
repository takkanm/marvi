# frozen_string_literal: true

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
        lines = ASTWalker.new.walk(markdown)
        lines.map { |line| render_line(line) }.join("\n") + "\n"
      end

      private

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
