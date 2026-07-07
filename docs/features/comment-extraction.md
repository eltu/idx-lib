# Comment Extraction

## Purpose

Extracts all comment nodes from source files alongside symbols, returning each
comment's full text plus its start and end line numbers. Useful for documentation
analysis, search indexing, and code-review tooling.

## API / Usage

```go
e := parser.NewSymbolExtractor()
result, err := e.Extract(src, "file.go")

// Iterate all comments
for _, c := range result.Comments {
    fmt.Printf("line %d-%d: %s\n", c.StartLine, c.EndLine, c.Context)
}

// Filter to semantic-only (skip separator lines like // ---- //)
for _, c := range result.Comments {
    if c.Context != "" {
        fmt.Println(c.Context)
    }
}
```

JSON shape (one element of `comments` array):

```json
{
  "context":    "Package foo provides ...",
  "start_line": 1,
  "end_line":   1
}
```

Decorative separator comments (lines containing only `-`, `=`, `*`, `+`, `|`,
`/`, `#`, space) are stripped and **not included** in the output.

`context` holds the normalized semantic text after stripping comment markers
(`//`, `///`, `//!`, `#`, `/*`, `*/`, leading ` * `). Consecutive adjacent
comment lines are merged into a single entry with context joined by newlines.

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
