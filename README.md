# idx-lib

A Go library that provides a **language-agnostic interface for parsing source code** powered by [Tree-sitter](https://tree-sitter.github.io/tree-sitter/). It decouples callers from language-specific grammars behind a clean, composable API.

---

## Features

- Unified `Parser` interface for any supported programming language
- Language auto-detection from file extension or content
- Token-level output with kind classification (`keyword`, `identifier`, `literal`, `operator`, `comment`)
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
    "github.com/eltu/idx-lib/parser"
    "github.com/eltu/idx-lib/internal/features/lang"
)

// Wire up your Detector and Tokenizer implementations.
svc := lang.NewParseService(detector, tokenizer)

result, err := svc.Parse(lang.SourceFile{
    Content:   []byte(`package main\n\nfunc main() {}`),
    Extension: ".go",
})
if err != nil {
    log.Fatal(err)
}

fmt.Println(result.LanguageID)   // "go"
fmt.Println(len(result.Tokens))  // number of tokens found
```

---

## API overview

### `parser` package — public surface

| Type | Description |
|---|---|
| `Parser` | Interface: `Parse(src []byte) (Result, error)` |
| `Result` | Holds `Language` and `[]Token` |
| `Token` | Lexical unit with `Kind`, `Value`, `Line`, `Col` |
| `TokenKind` | Enum: `keyword`, `identifier`, `literal`, `operator`, `comment`, `unknown` |
| `Language` | `Name` + `Extension` pair |

### `internal/features/lang` package — core domain

| Type | Description |
|---|---|
| `ParseService` | Orchestrates detection + tokenization |
| `Detector` | Port: `Detect(file SourceFile) ID` |
| `Tokenizer` | Port: `Tokenize(file SourceFile) ([]RawToken, error)` |
| `ID` | Canonical language identifier (`"go"`, `"python"`, …) |
| `SourceFile` | Raw bytes + extension |
| `ParseResult` | `LanguageID` + `[]RawToken` |

Implement `Detector` and `Tokenizer` with any Tree-sitter grammar binding, then inject them into `NewParseService`.

---

## Project structure

```
.
├── parser/                          # Public API (Parser interface + types)
├── internal/
│   └── features/
│       └── lang/
│           ├── domain.go            # Data types
│           ├── port.go              # Detector & Tokenizer interfaces
│           └── service.go           # ParseService (business logic)
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
