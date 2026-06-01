# frozen_string_literal: true

require "test_helper"

class TestMarvi < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Marvi::VERSION
  end

  def setup
    @renderer = Marvi::Renderer::ANSI.new
  end

  def test_renders_header
    output = @renderer.render("# Hello")
    assert_includes output, "# "
    assert_includes output, "Hello"
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
    assert_includes output, "puts"
    assert_includes output, "'hello'"
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

  def test_renders_table_with_multibyte_content
    md = "| 名前 | 年齢 |\n|------|------|\n| 田中 | 30   |\n| ボブ | 25   |\n"
    output = @renderer.render(md)

    border_lines = output.split("\n").select { |l| l.match?(/\A\e\[[\d;]+m[┌├└]/) }
    widths = border_lines.map { |l| Unicode::DisplayWidth.of(l.gsub(/\e\[[\d;]+m/, "")) }
    assert_equal 1, widths.uniq.size, "Table border lines must share the same display width"
  end

  def test_long_bullet_item_wraps_within_max_width
    max_width = 40
    md = "- これは非常に長い箇条書きの項目で画面幅を超えるはずなので折り返しが必要になります\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end
    assert_operator plain_lines.size, :>=, 2, "long bullet must wrap into multiple lines"
    assert plain_lines.first.start_with?("• "), "first line must keep the bullet marker"
    plain_lines[1..].each do |line|
      refute line.start_with?("•"), "continuation lines must not start with a bullet: #{line.inspect}"
      assert line.start_with?("  "), "continuation lines must be indented under the bullet content: #{line.inspect}"
    end
  end

  def test_long_ordered_list_item_wraps_within_max_width
    max_width = 40
    md = "1. これは非常に長い番号付きリストの項目で画面幅を超えるはずなので折り返しが必要になります\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end
    assert plain_lines.first.start_with?("1. "), "first line must keep the ordered marker"
    assert_operator plain_lines.size, :>=, 2, "long ordered item must wrap into multiple lines"
  end

  def test_nested_list_item_wraps_with_hanging_indent
    max_width = 40
    md = "- outer\n  - これは長いネストされた項目で画面幅を超えるはずなので折り返しが必要になります\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end
    nested_first = plain_lines.find { |l| l.include?("これは長い") }
    assert nested_first&.start_with?("  • "), "nested bullet must be indented under outer item: #{nested_first.inspect}"
  end

  def test_long_paragraph_wraps_within_max_width
    max_width = 40
    md = "これは非常に長い段落で画面幅を超えるはずなので折り返しが必要になります。\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end
    assert_operator plain_lines.size, :>=, 2, "long paragraph must wrap into multiple lines"
  end

  def test_long_header_wraps_within_max_width
    max_width = 40
    md = "# これは非常に長い見出しで画面幅を超えるはずなので折り返しが必要です\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end
    assert plain_lines.first.start_with?("# "), "first line must keep the # marker"
    assert_operator plain_lines.size, :>=, 2, "long header must wrap into multiple lines"
  end

  def test_long_blockquote_wraps_within_max_width
    max_width = 40
    md = "> これは非常に長い引用文で画面幅を超えるはずなので折り返しが必要になります。\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
      assert line.start_with?("│"), "every blockquote line must start with the │ prefix: #{line.inspect}"
    end
    assert_operator plain_lines.size, :>=, 2, "long blockquote must wrap into multiple lines"
  end

  def test_table_wraps_long_cell_within_max_width
    max_width = 40
    md = "| 項目 | 説明 |\n|------|------|\n" \
         "| 詳細 | これは非常に長い日本語の文章なので折り返しが必要になります。 |\n"
    lines = Marvi::ASTWalker.new.walk(md, max_width: max_width)
    plain_lines = lines.map(&:plain_text).reject(&:empty?)

    plain_lines.each do |line|
      assert_operator Unicode::DisplayWidth.of(line), :<=, max_width,
        "line exceeds max_width: #{line.inspect}"
    end

    border_lines = plain_lines.select { |l| l.start_with?("┌", "├", "└") }
    border_widths = border_lines.map { |l| Unicode::DisplayWidth.of(l) }
    assert_equal 1, border_widths.uniq.size, "borders must share width"

    body_lines = plain_lines.select { |l| l.start_with?("│") }
    body_widths = body_lines.map { |l| Unicode::DisplayWidth.of(l) }
    assert_equal 1, body_widths.uniq.size, "body rows must share width"
    assert_equal border_widths.first, body_widths.first, "borders and body must align"

    assert_operator body_lines.size, :>=, 3, "long cell must wrap into multiple visual rows"
  end
end
