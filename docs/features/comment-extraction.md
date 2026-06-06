# Comment Extraction

## Purpose

Extracts all comment nodes from source files alongside symbols, returning each
comment's full text plus its start and end line numbers. Useful for documentation
analysis, search indexing, and code-review tooling.

## API / Usage

```go
e := parser.NewSymbolExtractor()
result, err := e.Extract(src, ".go")
// result.Comments contains all extracted comments
for _, c := range result.Comments {
    fmt.Printf("line %d-%d: %s\n", c.StartLine, c.EndLine, c.Text)
}
```

JSON shape (one element of `comments` array):

```json
{
  "text":       "// Package foo provides ...",
  "start_line": 1,
  "end_line":   1
}
```

`text` is the raw source text of the comment node, including delimiters
(`//`, `/* */`, `#`, etc.).

## Supported languages and node types

| Language   | Comment node types                              |
|------------|-------------------------------------------------|
| Go         | `comment` (`//` and `/* */`)                   |
| Python     | `comment` (`#` lines)                          |
| JavaScript | `comment` (`//` and `/* */`)                   |
| TypeScript | `comment` (`//` and `/* */`)                   |
| Java       | `line_comment` (`//`), `block_comment` (`/* */`) |
| Ruby       | `comment` (`#` lines)                          |
| Rust       | `line_comment` (`//`), `block_comment` (`/* */`), `doc_comment` (`///`) |

## Limitations / known constraints

- Python `"""docstrings"""` are string literals in the AST, not `comment` nodes;
  they are **not** included in the output.
- Multi-line block comments (`/* ... */`) are returned as a single `Comment` entry
  spanning all lines (`StartLine` to `EndLine`).
- Comment order in the result follows document order (top to bottom).
