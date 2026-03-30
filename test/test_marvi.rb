# frozen_string_literal: true

require "test_helper"

class TestMarvi < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Marvi::VERSION
  end

  def setup
    @renderer = Marvi::Renderer.new
  end

  def test_renders_header
    output = @renderer.render("# Hello")
    assert_includes output, "# Hello"
    assert_includes output, Marvi::ANSI::BOLD
  end

  def test_renders_paragraph
    output = @renderer.render("Hello world")
    assert_includes output, "Hello world"
  end

  def test_renders_bold
    output = @renderer.render("**bold**")
    assert_includes output, Marvi::ANSI::BOLD
    assert_includes output, "bold"
  end

  def test_renders_italic
    output = @renderer.render("*italic*")
    assert_includes output, Marvi::ANSI::ITALIC
    assert_includes output, "italic"
  end

  def test_renders_inline_code
    output = @renderer.render("`code`")
    assert_includes output, "code"
    assert_includes output, Marvi::ANSI::CYAN
  end

  def test_renders_code_block
    output = @renderer.render("```ruby\nputs 'hello'\n```\n")
    assert_includes output, "puts 'hello'"
    assert_includes output, Marvi::ANSI::GREEN
  end

  def test_renders_unordered_list
    output = @renderer.render("- foo\n- bar")
    assert_includes output, "foo"
    assert_includes output, "bar"
    assert_includes output, "•"
  end

  def test_renders_ordered_list
    output = @renderer.render("1. first\n2. second")
    assert_includes output, "first"
    assert_includes output, "1."
  end

  def test_renders_blockquote
    output = @renderer.render("> quoted")
    assert_includes output, "quoted"
    assert_includes output, "│"
  end

  def test_renders_horizontal_rule
    output = @renderer.render("---")
    assert_includes output, "─"
  end

  def test_renders_table
    md = "| Name  | Age |\n|-------|-----|\n| Alice | 30  |\n"
    output = @renderer.render(md)
    assert_includes output, "Name"
    assert_includes output, "Alice"
    assert_includes output, "│"
    assert_includes output, "┌"
    assert_includes output, "└"
  end
end
