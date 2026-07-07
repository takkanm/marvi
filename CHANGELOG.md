## [Unreleased]

- Add a blank margin row between the tab bar and the document. Clicks on the margin row select the tab directly above it, giving each tab a taller effective click target.

## [0.8.0] - 2026-07-06

- Turn the `o` prompt into a file picker. It lists Markdown/text documents under the current directory and narrows the list as you type (all space-separated terms must match, case-insensitive); select with `C-n`/`C-p` or the arrow keys and open with `Enter`. Input starting with `/`, `~`, `./`, or `../` switches to explicit path entry with shell-style `Tab` completion, and selecting a directory descends into it.
- Open multiple files in tabs. Pass several files on the command line (`marvi a.md b.md`), and a tab bar with the file names appears at the top of the screen, wrapping to multiple rows when the terminal is narrow. Switch tabs with `Tab`/`Shift-Tab`, jump directly with `1`–`9`, or click a tab with the mouse. Press `o` to open another file in a new tab and `x` to close the current one. File-change polling covers every tab and marks updated ones with `●` in the bar.

## [0.7.0] - 2026-06-15

- Add incremental search to the curses pager. Press `/` to search as you type, with all matches highlighted (current match in bold) and the view jumping to the nearest match. Navigate matches with `n`/`N` (vi/less style); search is case-insensitive.

## [0.6.0] - 2026-06-11

- Render Mermaid fenced code blocks as Unicode box-drawing art. Supports `flowchart`/`graph` (TD/TB/LR/RL), `sequenceDiagram`, `classDiagram`, and `stateDiagram`/`stateDiagram-v2`. Unsupported diagram types, malformed syntax, and over-width output fall back to the highlighted code block.

## [0.5.0] - 2026-06-02

- Syntax-highlight fenced code blocks via [Rouge](https://github.com/rouge-ruby/rouge). Blocks without a language (or with an unknown one) fall back to the previous single-color rendering.
- Extend the dark code block background to the longest line so the block reads as a solid pane instead of a ragged shape.

## [0.4.2] - 2026-05-31

- Add left/right padding in the curses pager so content no longer sits flush against the terminal edges. Padding scales with terminal width.
- Render every line of a multi-line blockquote with its `│ ` prefix.
- Stop emitting an empty `│ ` line at the end of blockquotes.
- Collapse consecutive blank lines so block-level elements are separated by a single blank line.

## [0.4.1] - 2026-05-26

- Wrap long text in bulleted/ordered lists, paragraphs, headers, and blockquotes so it no longer overflows the terminal width. List items and headers use a hanging indent for continuation lines. (#1)

## [0.4.0] - 2026-05-18

- Bind `Ctrl-D` / `Ctrl-U` for vim-style half-page scrolling in the curses pager.

## [0.3.0] - 2026-05-18

- Render tables correctly when cells contain East Asian wide characters and emoji (uses `unicode-display_width`).
- Wrap long table cells to fit the terminal width so borders no longer break across physical lines; curses pager re-flows on window resize.

## [0.1.0] - 2026-03-17

- Initial release
