# frozen_string_literal: true

require "kramdown"
require "kramdown-parser-gfm"
require_relative "ansi"

module Marvi
  class Renderer
    def render(markdown)
      doc = Kramdown::Document.new(markdown, input: "GFM")
      render_element(doc.root)
    end

    private

    def render_element(el, indent: 0, list_type: nil, list_index: nil)
      case el.type
      when :root
        render_children(el).rstrip + "\n"
      when :header
        level = el.options[:level]
        color = ANSI::HEADER_COLORS[level - 1]
        prefix = "#" * level + " "
        "#{ANSI::BOLD}#{color}#{prefix}#{render_children(el)}#{ANSI::RESET}\n\n"
      when :p
        "#{render_children(el)}\n\n"
      when :ul
        el.children.map { |child| render_element(child, indent: indent, list_type: :ul) }.join + "\n"
      when :ol
        el.children.each_with_index.map do |child, i|
          render_element(child, indent: indent, list_type: :ol, list_index: i + 1)
        end.join + "\n"
      when :li
        bullet = list_type == :ol ? "#{list_index}." : "•"
        prefix = "  " * indent + "#{ANSI::CYAN}#{bullet}#{ANSI::RESET} "
        content = render_li_children(el, indent: indent)
        "#{prefix}#{content}\n"
      when :codeblock
        lang = el.options[:lang]
        header = lang ? "#{ANSI::YELLOW}#{lang}#{ANSI::RESET}\n" : ""
        lines = el.value.chomp.split("\n").map do |line|
          "  #{ANSI::BG_DARK}#{ANSI::GREEN} #{line} #{ANSI::RESET}"
        end
        "#{header}#{lines.join("\n")}\n\n"
      when :blockquote
        inner = render_children(el).chomp
        inner.gsub(/^/, "#{ANSI::CYAN}│#{ANSI::RESET} ") + "\n\n"
      when :text
        el.value
      when :strong
        "#{ANSI::BOLD}#{render_children(el)}#{ANSI::RESET}"
      when :em
        "#{ANSI::ITALIC}#{render_children(el)}#{ANSI::RESET}"
      when :codespan
        "#{ANSI::BG_DARK}#{ANSI::CYAN} #{el.value} #{ANSI::RESET}"
      when :br
        "\n"
      when :hr
        "#{ANSI::CYAN}#{"─" * 60}#{ANSI::RESET}\n\n"
      when :blank
        ""
      else
        render_children(el)
      end
    end

    def render_children(el, **opts)
      el.children.map { |child| render_element(child, **opts) }.join
    end

    # Render li children, separating nested lists from inline content
    def render_li_children(el, indent:)
      el.children.map do |child|
        if child.type == :ul || child.type == :ol
          "\n" + render_element(child, indent: indent + 1, list_type: child.type)
        elsif child.type == :p
          render_children(child).strip
        else
          render_element(child)
        end
      end.join
    end
  end
end
