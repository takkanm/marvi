# frozen_string_literal: true

module Marvi
  module ANSI
    RESET = "\e[0m"
    BOLD = "\e[1m"
    ITALIC = "\e[3m"
    CYAN = "\e[36m"
    YELLOW = "\e[33m"
    GREEN = "\e[32m"
    MAGENTA = "\e[35m"
    WHITE = "\e[37m"
    BG_DARK = "\e[48;5;236m"

    HEADER_COLORS = [CYAN, GREEN, YELLOW, MAGENTA, WHITE, WHITE].freeze
  end
end
