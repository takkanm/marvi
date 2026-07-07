# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class TestTabBar < Minitest::Test
  TabBar = Marvi::Renderer::Curses::TabBar

  def test_single_row_when_labels_fit
    items = TabBar.layout(%w[a.md b.md], 40)

    assert_equal [0, 0], items.map(&:row)
    assert_equal 0, items[0].col
    assert_equal 6, items[1].col # after " a.md "
    assert_equal 1, TabBar.rows(items)
  end

  def test_wraps_to_next_row_when_width_exceeded
    items = TabBar.layout(%w[aaaa.md bbbb.md cccc.md], 20)

    assert_equal [0, 0, 1], items.map(&:row)
    assert_equal 0, items[2].col
    assert_equal 2, TabBar.rows(items)
  end

  def test_multibyte_labels_use_display_width
    # Each CJK character occupies two columns, so two labels do not fit in 20.
    items = TabBar.layout(%w[日本語ファイル.md 日本語ファイル.md], 20)

    assert_equal [0, 1], items.map(&:row)
  end

  def test_label_longer_than_screen_is_truncated
    items = TabBar.layout(["a-very-long-file-name.md"], 10)

    assert_equal 1, items.size
    assert_operator items[0].width, :<=, 10
  end

  def test_item_at_finds_tab_by_coordinates
    items = TabBar.layout(%w[aaaa.md bbbb.md cccc.md], 20)

    assert_equal 0, TabBar.item_at(items, 0, 0).index
    assert_equal 1, TabBar.item_at(items, 0, items[1].col).index
    assert_equal 2, TabBar.item_at(items, 1, 3).index
    assert_nil TabBar.item_at(items, 1, 19)
  end

  def test_rows_of_empty_layout
    assert_equal 0, TabBar.rows([])
  end

  def test_item_for_click_includes_margin_row_below_bar
    items = TabBar.layout(%w[aaaa.md bbbb.md cccc.md], 20)

    # rows 0-1 are the bar; row 2 is the margin row under the last bar row
    assert_equal 2, TabBar.item_for_click(items, 2, 3).index
    # margin clicks outside any tab's columns hit nothing
    assert_nil TabBar.item_for_click(items, 2, 15)
    # rows past the margin are the document, never a tab
    assert_nil TabBar.item_for_click(items, 3, 3)
    # direct hits still resolve
    assert_equal 0, TabBar.item_for_click(items, 0, 0).index
  end
end

class TestTab < Minitest::Test
  Tab = Marvi::Renderer::Curses::Tab

  PAGE = 5
  WIDTH = 40

  def build_tab(markdown)
    tab = Tab.new(markdown: markdown)
    tab.ensure_walked(WIDTH, PAGE)
    tab
  end

  def many_lines_markdown(count = 30)
    (1..count).map { |i| "line#{i}\n\n" }.join
  end

  def test_label_uses_basename_or_stdin
    assert_equal "(stdin)", Tab.new(markdown: "hi").label

    Tempfile.create(["doc", ".md"]) do |f|
      f.write("# hi\n")
      f.flush
      assert_equal File.basename(f.path), Tab.new(file: f.path).label
    end
  end

  def test_scroll_is_clamped_to_content
    tab = build_tab(many_lines_markdown)

    tab.scroll_by(1000, PAGE)
    assert_equal tab.max_scroll(PAGE), tab.scroll

    tab.scroll_by(-1000, PAGE)
    assert_equal 0, tab.scroll
  end

  def test_rewalk_at_same_width_is_skipped
    tab = build_tab("hello\n")
    lines = tab.lines
    tab.ensure_walked(WIDTH, PAGE)

    assert_same lines, tab.lines
  end

  def test_rewalk_at_new_width_rebuilds_lines
    tab = build_tab("word " * 30)
    before = tab.lines.size
    tab.ensure_walked(20, PAGE)

    refute_equal before, tab.lines.size
  end

  def test_search_finds_matches_and_scrolls_to_first
    tab = build_tab(many_lines_markdown)

    tab.update_search("line25", PAGE)
    assert_equal 1, tab.matches.size
    assert_equal 0, tab.current_match
    assert_operator tab.scroll, :>, 0
  end

  def test_jump_match_wraps_around
    tab = build_tab("target one\n\ntarget two\n")

    tab.update_search("target", PAGE)
    tab.jump_match(1, PAGE)
    assert_equal 1, tab.current_match
    tab.jump_match(1, PAGE)
    assert_equal 0, tab.current_match
  end

  def test_commit_search_clears_when_no_matches
    tab = build_tab("hello\n")

    tab.update_search("nope", PAGE)
    tab.commit_search
    assert_nil tab.search_query
    assert_empty tab.matches
  end

  def test_reload_picks_up_file_changes
    Tempfile.create(["doc", ".md"]) do |f|
      f.write("before\n")
      f.flush
      tab = Tab.new(file: f.path)
      tab.ensure_walked(WIDTH, PAGE)
      assert_includes tab.lines.map(&:plain_text).join, "before"

      File.write(f.path, "after\n")
      tab.reload(WIDTH, PAGE)
      assert_includes tab.lines.map(&:plain_text).join, "after"
      refute tab.file_updated?
    end
  end

  def test_check_file_updated_flags_mtime_change
    Tempfile.create(["doc", ".md"]) do |f|
      f.write("v1\n")
      f.flush
      tab = Tab.new(file: f.path)

      refute tab.check_file_updated

      File.write(f.path, "v2\n")
      FileUtils.touch(f.path, mtime: Time.now + 2)
      assert tab.check_file_updated
      assert tab.file_updated?
      # already flagged: further changes do not re-raise the flag
      FileUtils.touch(f.path, mtime: Time.now + 4)
      refute tab.check_file_updated
    end
  end

  def test_stdin_tab_never_reports_updates
    tab = Tab.new(markdown: "hi")

    refute tab.check_file_updated
    refute tab.file_updated?
  end
end
