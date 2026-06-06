# Symbol Extraction

## Purpose

Parses source code files and extracts all named constructs — functions, methods, classes,
structs, interfaces, enums, and modules — with their start and end line numbers. The output
is designed to feed a BM25 search engine, enabling queries like "show me all functions that
contain 'payment' in their name" across an indexed codebase.

## API / Usage

### Extracting symbols

```go
e := parser.NewSymbolExtractor()
src := []byte(`
func NewUser(id, name string) (*User, error) { ... }
type User struct { ... }
`)

result, err := e.Extract(src, ".go")
if err != nil {
    log.Fatal(err)
}

// Serialise to JSON
data, _ := json.MarshalIndent(result, "", "  ")
fmt.Println(string(data))
```

Example output:

```json
{
  "language": { "name": "go", "extension": ".go" },
  "symbols": [
    { "name": "NewUser", "kind": "function", "start_line": 2, "end_line": 2 },
    { "name": "User",    "kind": "struct",   "start_line": 3, "end_line": 3 }
  ]
}
```

### Filtering symbols

Use `parser.Filter` to narrow results by kind and/or name substring (case-insensitive):

```go
// All functions whose name contains "get"
fns := parser.Filter{
    Kinds:        []parser.SymbolKind{parser.SymbolFunction},
    NameContains: "get",
}.Apply(result)

// All constructs — no filter
all := parser.Filter{}.Apply(result)
```

`Filter.Apply` is pure: it never mutates the input `ExtractResult`.

### SymbolKind values

| Constant              | JSON value    | Languages                                    |
|-----------------------|---------------|----------------------------------------------|
| `parser.SymbolFunction`  | `"function"`  | Go, Python, JS, TS, Java, Rust               |
| `parser.SymbolMethod`    | `"method"`    | Go, JS, TS, Java, Ruby                       |
| `parser.SymbolClass`     | `"class"`     | Python, JS, TS, Java, Ruby                   |
| `parser.SymbolStruct`    | `"struct"`    | Go, Rust                                     |
| `parser.SymbolInterface` | `"interface"` | Go, TS, Java, Rust (trait)                   |
| `parser.SymbolEnum`      | `"enum"`      | TS, Java, Rust                               |
| `parser.SymbolModule`    | `"module"`    | Ruby                                         |

## Supported languages (v1)

| Language   | Extension | Notes                                              |
|------------|-----------|-----------------------------------------------------|
| Go         | `.go`     | Functions, methods, structs, interfaces            |
| Python     | `.py`     | Functions and methods both reported as `function`  |
| JavaScript | `.js`     | Arrow functions assigned to `const`/`let` included |
| TypeScript | `.ts`     | Includes interfaces and enums                      |
| Java       | `.java`   | Includes constructors as `function`                |
| Ruby       | `.rb`     | Modules reported as `module`                       |
| Rust       | `.rs`     | Traits reported as `interface`; impl methods TBD   |

## Limitations / known constraints

- **CGO required.** The tree-sitter backend requires a C compiler. Builds with
  `CGO_ENABLED=0` are not supported.
- **Unsupported extensions return empty results, not errors.** Passing `.dart`, `.html`,
  or any other unregistered extension returns `ExtractResult{Symbols: nil}`.
- **Python method vs. function distinction is not implemented in v1.** All `def` inside
  a class body are classified as `function`, not `method`. This will be addressed in a
  follow-up (see ADR 0001).
- **Rust `impl` methods are not extracted in v1.** Only top-level `fn`, `struct`, `enum`,
  and `trait` items are captured.
- **Line numbers are 1-indexed.**
- **Anonymous closures and lambda expressions are not extracted**, except arrow functions
  directly assigned to a named variable in JavaScript/TypeScript.
- **Tree-sitter is error-tolerant**: symbols are extracted even from files with syntax
  errors. The parser inserts ERROR nodes but continues; names adjacent to errors may be
  incomplete.
