# frozen_string_literal: true

require_relative "marvi/version"
require_relative "marvi/ansi"
require_relative "marvi/document"
require_relative "marvi/ast_walker"
require_relative "marvi/renderer/ansi"
require_relative "marvi/renderer/curses"

module Marvi
  class Error < StandardError; end
end
