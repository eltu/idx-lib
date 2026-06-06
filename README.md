# idx-lib

A Go library that provides a **language-agnostic interface for parsing source code** powered by [Tree-sitter](https://tree-sitter.github.io/tree-sitter/). It decouples callers from language-specific grammars behind a clean, composable API.

---

## Features

- Symbol extraction (functions, methods, structs, classes, interfaces, enums, modules) with line ranges
- Language auto-detection from file extension
- Composable `Filter` to narrow results by kind and/or name substring
- Hexagonal architecture — swap grammar implementations without touching business logic
- Test corpus of 25 language fixture files for integration and end-to-end testing

---

## Requirements

- Go 1.24+
- `golangci-lint` (installed automatically via `make hooks`)

---

## Installation

```sh
go get github.com/eltu/idx-lib
```

---

## Quick start

```go
import (
    "fmt"
    "log"
    "os"

    "github.com/eltu/idx-lib/parser"
)

src, err := os.ReadFile("service.go")
if err != nil {
    log.Fatal(err)
}

e := parser.NewSymbolExtractor()
result, err := e.Extract(src, "service.go")
if err != nil {
    log.Fatal(err)
}

fmt.Println(result.Language.Name) // "go"

for _, sym := range result.Symbols {
    fmt.Printf("%s %s (lines %d–%d)\n", sym.Kind, sym.Name, sym.StartLine, sym.EndLine)
}
```

### Filtering symbols

```go
fns := parser.Filter{
    Kinds:        []parser.SymbolKind{parser.SymbolFunction},
    NameContains: "user",
}.Apply(result)

for _, sym := range fns.Symbols {
    fmt.Println(sym.Name) // only functions whose name contains "user"
}
```

---

## API overview

### `parser` package — public surface

| Type / Constructor | Description |
|---|---|
| `NewSymbolExtractor()` | Returns a `SymbolExtractor` backed by tree-sitter |
| `SymbolExtractor` | Interface: `Extract(src []byte, filePath string) (ExtractResult, error)` |
| `ExtractResult` | Holds `FilePath`, `Language`, `[]Symbol`, and `[]Comment` |
| `Symbol` | Named construct with `Name`, `Kind`, `StartLine`, `EndLine` |
| `SymbolKind` | Enum: `function`, `method`, `class`, `struct`, `interface`, `enum`, `module` |
| `Comment` | Extracted comment with `Context`, `StartLine`, `EndLine` |
| `Language` | `Name` + `Extension` pair |
| `Filter` | `Apply(ExtractResult) ExtractResult` — filters by `Kinds` and/or `NameContains` |

---

## Project structure

```
.
├── parser/                          # Public API (SymbolExtractor, Filter, types)
├── internal/
│   ├── features/
│   │   ├── lang/                    # Language detection domain
│   │   └── symbols/                 # Symbol extraction domain
│   ├── adapter/treesitter/          # Tree-sitter grammar registry and adapters
│   └── shared/                      # Cross-feature concerns
├── cmd/idx-parse/                   # CLI: reads a file and prints symbols as JSON
├── testdata/
│   └── fixtures/
│       ├── inventory.go             # Test helper: All() + MustReadFile()
│       └── src/                     # 25 language sample files
├── docs/
│   ├── adr/                         # Architecture Decision Records
│   └── features/                    # Per-feature usage documentation
└── Makefile
```

---

## Development

### Bootstrap (run once after cloning)

```sh
make hooks   # installs golangci-lint and git pre-push hook
```

### Daily workflow

| Command | Description |
|---|---|
| `make fmt` | Format all Go files with `gofmt` |
| `make lint` | Run `golangci-lint` |
| `make test` | Run all tests |
| `make coverage` | Run tests and generate `coverage.out` |
| `make complexity` | Fail if any function exceeds cyclomatic complexity 15 |
| `make check` | `fmt` + `lint` + `test` — same gate as CI and pre-push |

### Coverage gate

Total test coverage must stay **above 89%**. Verify after every change:

```sh
make coverage
go tool cover -func=coverage.out
```

If below the threshold, inspect uncovered lines and add tests before opening a PR:

```sh
go tool cover -html=coverage.out
```

---

## CI / CD

Every push and pull request runs:

1. **Cyclomatic complexity check** — fails if any function exceeds 15
2. **Unit tests with coverage** — uploaded to SonarCloud
3. **Security scan** — Snyk, SARIF results posted to GitHub Security tab

Releases are managed by [Release Please](https://github.com/googleapis/release-please) via conventional commits.

---

## Architecture decisions

Significant technical decisions are recorded as ADRs under [`docs/adr/`](docs/adr/). See [`docs/adr/README.md`](docs/adr/README.md) for the template and guidelines.

---

## Contributing

1. Fork the repo and create a branch from `main`.
2. Run `make hooks` to set up the pre-push gate.
3. Follow the conventions in [`CLAUDE.md`](CLAUDE.md) — code style, test structure, and documentation rules.
4. Every new feature needs a doc file in `docs/features/`. Every changed or removed feature must update or delete its doc.
5. Open a pull request. CI must pass before review.

---

## License

[MIT](LICENSE) © 2026 eltu
