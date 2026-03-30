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
