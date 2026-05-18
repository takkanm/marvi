## [Unreleased]

## [0.4.0] - 2026-05-18

- Bind `Ctrl-D` / `Ctrl-U` for vim-style half-page scrolling in the curses pager.

## [0.3.0] - 2026-05-18

- Render tables correctly when cells contain East Asian wide characters and emoji (uses `unicode-display_width`).
- Wrap long table cells to fit the terminal width so borders no longer break across physical lines; curses pager re-flows on window resize.

## [0.1.0] - 2026-03-17

- Initial release
