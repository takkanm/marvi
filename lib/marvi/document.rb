# frozen_string_literal: true

module Marvi
  class Span
    attr_reader :text, :bold, :italic, :color, :bg_color

    def initialize(text:, bold: false, italic: false, color: nil, bg_color: nil)
      @text = text
      @bold = bold
      @italic = italic
      @color = color
      @bg_color = bg_color
    end
  end

  class RichLine
    attr_reader :spans, :source_line

    def initialize(spans = [], source_line: nil)
      @spans = spans
      @source_line = source_line
    end

    def plain_text
      @spans.map(&:text).join
    end

    def self.blank
      new([])
    end
  end
end
