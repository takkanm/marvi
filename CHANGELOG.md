## [Unreleased]

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
