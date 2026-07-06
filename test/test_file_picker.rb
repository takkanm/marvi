# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class TestFilePicker < Minitest::Test
  FilePicker = Marvi::Renderer::Curses::FilePicker

  def with_tree
    Dir.mktmpdir do |dir|
      %w[
        README.md
        notes.txt
        docs/guide.md
        docs/api-reference.md
        sub/deep/design.md
        .hidden/secret.md
      ].each do |path|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, "# #{path}\n")
      end
      File.write(File.join(dir, "image.png"), "binary")
      yield dir, FilePicker.new(dir)
    end
  end

  def test_scans_documents_recursively_and_sorted
    with_tree do |_dir, picker|
      assert_equal %w[README.md docs/api-reference.md docs/guide.md notes.txt sub/deep/design.md],
        picker.all_files
    end
  end

  def test_scan_excludes_non_documents_and_hidden_dirs
    with_tree do |_dir, picker|
      refute_includes picker.all_files, "image.png"
      refute_includes picker.all_files, ".hidden/secret.md"
    end
  end

  def test_empty_input_lists_everything
    with_tree do |_dir, picker|
      assert_equal picker.all_files, picker.candidates("")
    end
  end

  def test_filter_is_case_insensitive_substring
    with_tree do |_dir, picker|
      assert_equal ["docs/guide.md"], picker.candidates("GUI")
    end
  end

  def test_filter_requires_all_terms
    with_tree do |_dir, picker|
      assert_equal ["docs/api-reference.md"], picker.candidates("docs api")
      assert_empty picker.candidates("docs nothing")
    end
  end

  def test_path_mode_detection
    picker = FilePicker.new
    assert picker.path_mode?("/usr/share")
    assert picker.path_mode?("~/notes")
    assert picker.path_mode?("./docs")
    assert picker.path_mode?("../other")
    refute picker.path_mode?("guide")
    refute picker.path_mode?("docs/guide.md")
  end

  def test_path_candidates_list_matching_entries_with_dir_slash
    with_tree do |dir, picker|
      Dir.chdir(dir) do
        assert_equal ["./docs/"], picker.candidates("./do")
        assert_equal ["./docs/api-reference.md", "./docs/guide.md"], picker.candidates("./docs/")
      end
    end
  end

  def test_complete_extends_to_common_prefix
    with_tree do |dir, picker|
      Dir.chdir(dir) do
        # single directory match completes through the trailing slash
        assert_equal "./docs/", picker.complete("./do")
        # multiple matches stop at the divergence point
        File.write("abc-one.md", "x")
        File.write("abc-two.md", "x")
        assert_equal "./abc-", picker.complete("./a")
      end
    end
  end

  def test_complete_keeps_input_when_no_match
    with_tree do |dir, picker|
      Dir.chdir(dir) do
        assert_equal "./zzz", picker.complete("./zzz")
      end
    end
  end
end
