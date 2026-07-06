# frozen_string_literal: true

module Marvi
  module Renderer
    class Curses
      # Candidate discovery, filtering, and tab-completion behind the `o`
      # (open file) picker. Pure filesystem/string logic with no curses calls,
      # so it can be tested headlessly.
      #
      # Two modes, decided per keystroke from the typed input:
      # - list mode: filter documents scanned under the base directory; every
      #   whitespace-separated term must match somewhere in the path.
      # - path mode (input starts with /, ~, ./ or ../): complete the typed
      #   path against the filesystem, shell-style.
      class FilePicker
        SCAN_GLOB = "**/*.{md,markdown,mdown,mkd,txt}"
        MAX_FILES = 2000

        def initialize(base_dir = Dir.pwd)
          @base_dir = base_dir
        end

        # Documents under the base directory, capped to keep the picker snappy
        # in huge trees. Dir.glob skips hidden directories by default.
        def all_files
          @all_files ||= Dir.glob(SCAN_GLOB, base: @base_dir)
            .reject { |path| File.directory?(File.join(@base_dir, path)) }
            .sort
            .first(MAX_FILES)
        end

        def path_mode?(input)
          input.start_with?("/", "~", "./", "../")
        end

        def candidates(input)
          path_mode?(input) ? path_candidates(input) : filter(input)
        end

        def filter(input)
          terms = input.downcase.split
          return all_files if terms.empty?

          all_files.select do |path|
            haystack = path.downcase
            terms.all? { |term| haystack.include?(term) }
          end
        end

        # Longest unambiguous extension of the typed path. A lone directory
        # match gains a trailing slash so the next Tab descends into it.
        def complete(input)
          cands = path_candidates(input)
          return input if cands.empty?

          prefix = common_prefix(cands)
          (prefix.length > input.length) ? prefix : input
        end

        private

        # Filesystem entries matching the typed fragment. Directories get a
        # trailing slash; a leading ~ in the input is preserved in the results.
        def path_candidates(input)
          home = Dir.home
          home_style = input.start_with?("~/") || input == "~"
          raw = home_style ? input.sub(/\A~/, home) : input
          Dir.glob("#{glob_escape(raw)}*").sort.map do |path|
            path = "#{path}/" if File.directory?(path)
            home_style ? path.sub(home, "~") : path
          end
        end

        def glob_escape(path)
          path.gsub(/[\[\]{}*?\\]/) { |ch| "\\#{ch}" }
        end

        def common_prefix(strings)
          strings.reduce do |prefix, s|
            i = 0
            i += 1 while i < prefix.length && i < s.length && prefix[i] == s[i]
            prefix[0, i]
          end
        end
      end
    end
  end
end
