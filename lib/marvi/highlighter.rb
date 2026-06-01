# frozen_string_literal: true

require "rouge"

module Marvi
  class Highlighter
    DEFAULT_COLOR = :white
    FALLBACK_COLOR = :green

    # Ordered so longer qualnames win over their prefixes (e.g. "Literal.String" before "Literal").
    TOKEN_COLOR_RULES = [
      ["Comment", :cyan],
      ["Keyword", :yellow],
      ["Literal.String", :green],
      ["Literal.Number", :magenta],
      ["Literal", :magenta],
      ["Name.Function", :cyan],
      ["Name.Class", :cyan],
      ["Name.Namespace", :cyan],
      ["Name.Tag", :cyan],
      ["Name.Attribute", :cyan],
      ["Name.Decorator", :cyan],
      ["Name.Constant", :magenta],
      ["Name.Builtin", :magenta],
      ["Operator", :white],
      ["Punctuation", :white],
      ["Error", :magenta]
    ].freeze

    COMMENT_PREFIX = "Comment"

    def self.lines(code, lang, bg_color: :dark)
      lexer = resolve_lexer(lang)
      return fallback(code, bg_color) if lexer.nil?
      tokens_to_lines(lexer.lex(code), bg_color)
    end

    def self.resolve_lexer(lang)
      return nil if lang.nil? || lang.empty?
      Rouge::Lexer.find(lang)
    rescue
      nil
    end

    def self.fallback(code, bg_color)
      code.split("\n", -1).map { |line| [Span.new(text: line, color: FALLBACK_COLOR, bg_color: bg_color)] }
    end

    def self.tokens_to_lines(tokens, bg_color)
      current = []
      lines = []
      tokens.each do |tok, val|
        color = token_color(tok)
        italic = comment?(tok)
        val.split("\n", -1).each_with_index do |part, idx|
          if idx > 0
            lines << current
            current = []
          end
          next if part.empty?
          current << Span.new(text: part, italic: italic, color: color, bg_color: bg_color)
        end
      end
      lines << current
      lines
    end

    def self.token_color(token)
      qual = token.qualname
      TOKEN_COLOR_RULES.each do |prefix, color|
        return color if qual == prefix || qual.start_with?("#{prefix}.")
      end
      DEFAULT_COLOR
    end

    def self.comment?(token)
      qual = token.qualname
      qual == COMMENT_PREFIX || qual.start_with?("#{COMMENT_PREFIX}.")
    end
  end
end
