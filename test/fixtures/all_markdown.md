# Heading Level 1

## Heading Level 2

### Heading Level 3

#### Heading Level 4

##### Heading Level 5

###### Heading Level 6

---

## Paragraphs

Plain paragraph text.

Paragraph with **bold text**, *italic text*, and ***bold italic text***.

Paragraph with `inline code` inside it.

Paragraph with a hard  
line break inside.

Paragraph with an HTML entity: &amp; and a smart quote: "Hello," she said.

---

## Horizontal Rules

Above is a horizontal rule. Below is another.

---

## Unordered Lists

- Item one
- Item two
- Item three

Nested unordered list:

- Parent item A
  - Child item A-1
  - Child item A-2
    - Grandchild item A-2-a
- Parent item B
  - Child item B-1

---

## Ordered Lists

1. First item
2. Second item
3. Third item

Nested ordered list:

1. Step one
   1. Sub-step one-a
   2. Sub-step one-b
2. Step two
   1. Sub-step two-a

Mixed nesting:

1. Ordered parent
   - Unordered child
   - Another unordered child
- Unordered parent
  1. Ordered child
  2. Another ordered child

---

## Code Blocks

Fenced code block without language:

```
plain code block
no syntax highlighting
```

Fenced code block with Ruby:

```ruby
def greet(name)
  puts "Hello, #{name}!"
end

greet("world")
```

Fenced code block with JavaScript:

```javascript
const greet = (name) => {
  console.log(`Hello, ${name}!`);
};

greet("world");
```

Fenced code block with shell:

```sh
echo "Hello, world!"
ls -la
```

---

## Blockquotes

> Simple blockquote.

> Blockquote with **bold** and *italic* text.

> Blockquote line one.
> Blockquote line two.

> Nested blockquote outer.
>
> > Nested blockquote inner.

> Blockquote with a list:
>
> - Item one
> - Item two

---

## Tables

### Basic Table

| Name    | Age | City      |
| ------- | --- | --------- |
| Alice   | 30  | Tokyo     |
| Bob     | 25  | Osaka     |
| Charlie | 35  | Kyoto     |

### Column Alignment (Left / Center / Right)

| Left-aligned | Center-aligned | Right-aligned |
| :----------- | :------------: | ------------: |
| Apple        |     Banana     |        Cherry |
| Dog          |      Cat       |          Bird |
| Elephant     |   Flamingo     |         Gecko |

### Table with Inline Formatting

| Feature            | Status        | Notes                            |
| ------------------ | ------------- | -------------------------------- |
| **Bold header**    | *italic*      | `inline code`                    |
| Plain text         | **Done**      | No special formatting            |
| *Emphasis*         | Pending       | See **details** below            |
| ***Bold italic***  | `code status` | Both **bold** and *italic* mixed |

### Wide Table (Many Columns)

| ID  | Name          | Department   | Role             | Level  | Location | Remote | Start Date |
| --- | ------------- | ------------ | ---------------- | ------ | -------- | ------ | ---------- |
| 001 | Alice Smith   | Engineering  | Backend Engineer | Senior | Tokyo    | Yes    | 2020-04-01 |
| 002 | Bob Johnson   | Design       | UX Designer      | Mid    | Osaka    | No     | 2021-07-15 |
| 003 | Carol White   | Engineering  | Frontend Engineer| Junior | Remote   | Yes    | 2023-01-10 |
| 004 | Dave Brown    | Product      | Product Manager  | Lead   | Tokyo    | No     | 2019-10-01 |
| 005 | Eve Davis     | Engineering  | SRE              | Senior | Kyoto    | Yes    | 2018-03-20 |

### Table with Long Cell Content

| Category      | Description                                                               | Example                          |
| ------------- | ------------------------------------------------------------------------- | -------------------------------- |
| Short         | Brief                                                                     | Hi                               |
| Medium length | A moderately long description that spans a bit more space                 | Hello world                      |
| Very long     | This is a significantly longer cell value used to test wide column layout | The quick brown fox jumps over   |
| Mixed widths  | Column widths should adapt to the longest content in each column          | Lazy dog                         |

### Multibyte (CJK) Table with Long Content

| 項目     | 説明                                                                                                                                                                                       | 担当者       |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ |
| 概要     | マルチバイト文字を含む表の描画を検証するテストケース                                                                                                                                       | 田中 太郎    |
| 詳細説明 | この行は意図的に非常に長い日本語の文章を含んでおり、標準的なターミナル幅(80 桁)を確実に超えて折り返しが必要になることを想定しています。罫線の整列、padding の計算、そして折り返し時の挙動を一度に検証するための行です。 | 佐藤 花子    |
| 備考     | 絵文字 🍣🎉 や全角記号「」『』、半角と全角の混在 (Ruby と るびー) なども含めて確認します                                                                                                   | 鈴木 一郎    |

### Numeric / Financial Table

| Quarter | Revenue (¥M) | Expenses (¥M) | Profit (¥M) | Growth (%) |
| ------- | -----------: | ------------: | ----------: | ---------: |
| Q1 2024 |        1,200 |           900 |         300 |       +8.5 |
| Q2 2024 |        1,350 |           950 |         400 |      +12.5 |
| Q3 2024 |        1,100 |         1,050 |          50 |       -6.3 |
| Q4 2024 |        1,800 |         1,100 |         700 |      +25.0 |
| Total   |        5,450 |         4,000 |       1,450 |      +10.2 |

### Comparison Table (Feature Matrix)

| Feature              | Free Plan | Pro Plan | Enterprise |
| -------------------- | :-------: | :------: | :--------: |
| Users                |     1     |    10    |  Unlimited |
| Storage              |   5 GB    |  100 GB  |    1 TB    |
| API Access           |    No     |   Yes    |    Yes     |
| Custom Domain        |    No     |   Yes    |    Yes     |
| SSO / SAML           |    No     |    No    |    Yes     |
| Priority Support     |    No     |   Yes    |    Yes     |
| SLA                  |    No     |   99.9%  |   99.99%   |
| Audit Logs           |    No     |    No    |    Yes     |

### Status / Emoji-like Table

| Task                    | Owner   | Priority | Status      | Due Date   |
| ----------------------- | ------- | -------- | ----------- | ---------- |
| Design mockup           | Alice   | High     | Done        | 2026-04-01 |
| Implement API           | Bob     | High     | In Progress | 2026-05-15 |
| Write unit tests        | Carol   | Medium   | Todo        | 2026-05-20 |
| Deploy to staging       | Dave    | Medium   | Blocked     | 2026-05-22 |
| Performance review      | Eve     | Low      | Todo        | 2026-06-01 |

### Two-column Key-Value Table

| Key         | Value               |
| ----------- | ------------------- |
| Version     | 0.1.1               |
| License     | MIT                 |
| Language    | Ruby                |
| Platform    | macOS / Linux       |
| Maintainer  | Mitsutaka Mimura    |

### Single-column Table

| Supported Markdown Elements |
| --------------------------- |
| Heading (h1–h6)             |
| Paragraph                   |
| Unordered list              |
| Ordered list                |
| Nested list                 |
| Code block (fenced)         |
| Inline code                 |
| Blockquote                  |
| Horizontal rule             |
| Table                       |
| Bold / Italic               |
| Hard line break             |

### Table with Mixed Inline Styles in Every Cell

| A                | B               | C                    | D                  |
| ---------------- | --------------- | -------------------- | ------------------ |
| **Bold A1**      | *Italic B1*     | `Code C1`            | Plain D1           |
| *Italic A2*      | `Code B2`       | Plain C2             | **Bold D2**        |
| `Code A3`        | Plain B3        | **Bold C3**          | *Italic D3*        |
| Plain A4         | **Bold B4**     | *Italic C4*          | `Code D4`          |
| ***BoldItal A5***| ***BoldItal B5***| ***BoldItal C5***  | ***BoldItal D5***  |

### Table Immediately Following a Code Block

```ruby
results = query.all
```

| ID | Result  | Count |
| -- | ------- | ----: |
| 1  | success |   100 |
| 2  | failure |     5 |
| 3  | pending |    12 |

### Table Immediately Following a Blockquote

> The following table shows benchmark results.

| Benchmark       | Time (ms) | Memory (MB) | Notes           |
| --------------- | --------: | ----------: | --------------- |
| parse_small     |       0.5 |           2 | 100-line input  |
| parse_medium    |       4.2 |          12 | 1000-line input |
| parse_large     |      38.7 |          95 | 10000-line input|
| render_ansi     |       1.1 |           4 | ANSI output     |
| render_curses   |       2.3 |           8 | curses output   |

---

## Inline Elements Summary

| Element        | Syntax               | Rendered Example         |
| -------------- | -------------------- | ------------------------ |
| Bold           | `**text**`           | **bold**                 |
| Italic         | `*text*`             | *italic*                 |
| Bold + Italic  | `***text***`         | ***bold italic***        |
| Inline code    | `` `code` ``         | `code`                   |
| Hard line break| two trailing spaces  | (see paragraph section)  |
| Smart quote    | `"text"`             | "quoted"                 |
| HTML entity    | `&amp;`              | &amp;                    |

---

## Mixed Content

Paragraph before a list:

- Item with `code` and **bold**
- Item with *italic* text
  - Nested item with ***bold italic***

> Blockquote containing a table:
>
> | A | B |
> | - | - |
> | 1 | 2 |

Paragraph after blockquote.

1. Ordered item referencing `code`
2. Another item with **emphasis**

---

## Edge Cases

Empty-ish paragraph followed by a rule:

 

---

List items with paragraph-style content:

- First list item

- Second list item (separated by blank line)

- Third list item

Code block immediately after heading:

### Code Right After Heading

```
code immediately after heading
```

Table immediately after heading:

### Table Right After Heading

| X | Y |
| - | - |
| 1 | 2 |

Blockquote immediately after heading:

### Blockquote Right After Heading

> Quoted text.
