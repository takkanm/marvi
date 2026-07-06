# Marvi

Marvi is a terminal Markdown renderer. It parses Markdown and displays it with ANSI colors and styles directly in your terminal.

## Installation

```bash
gem install marvi
```

Or add to your Gemfile:

```bash
bundle add marvi
```

## Usage

### CLI

Render a Markdown file:

```bash
marvi README.md
```

Open multiple files at once — each file gets its own tab in a bar at the top of the screen (the bar wraps to multiple rows when tabs don't fit the terminal width):

```bash
marvi README.md CHANGELOG.md docs/guide.md
```

Tab keys inside the pager:

| Key | Action |
| --- | --- |
| `Tab` / `Shift-Tab` | next / previous tab |
| `1`–`9` | jump to tab by number |
| mouse click on a tab | switch to that tab |
| `o` | open a file in a new tab |
| `x` | close the current tab (closing the last one quits) |

Read from stdin:

```bash
cat README.md | marvi
echo "# Hello **world**" | marvi
```

### Ruby API

```ruby
require "marvi"

markdown = File.read("README.md")
puts Marvi::Renderer.new.render(markdown)
```

## Supported Markdown elements

- Headings (`#`, `##`, `###`, ...)
- Bold (`**text**`) and italic (`*text*`)
- Inline code (`` `code` ``)
- Code blocks (` ``` `)
- Unordered and ordered lists
- Blockquotes (`> text`)
- Horizontal rules (`---`)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt.

```bash
bin/setup
rake test
bin/console
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/takkanm/marvi.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
