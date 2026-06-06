# 0001 — Use tree-sitter for multi-language symbol extraction

**Status:** Accepted
**Date:** 2026-06-05

## Context

idx-lib must extract named constructs (functions, classes, structs, interfaces, enums, modules)
from source files written in multiple programming languages, producing structured output
suitable for indexing in a BM25 search engine.

Three approaches were considered:

1. **Regex-based matching** — simple to implement but fragile: fails on nested constructs,
   multiline declarations, and comments that contain keyword-like text.

2. **Per-language AST libraries** (`go/ast`, `pythonparser`, `java-parser`, etc.) — accurate
   but requires one dependency per language, each with its own API surface to wrap.

3. **Tree-sitter via `github.com/smacker/go-tree-sitter`** — single dependency that bundles
   grammars for 15+ languages. Uses a declarative S-expression query language that is
   uniform across languages.

## Decision

Use `github.com/smacker/go-tree-sitter`. It covers all target languages from one Go module,
produces accurate parse trees even for syntactically incomplete code (tree-sitter is
error-tolerant by design), and allows adding a new language by registering one entry in the
`Registry` plus one `.scm` query file — no Go code changes required for the extraction logic.

The library is wrapped behind the `symbols.Extractor` port, so the tree-sitter implementation
can be replaced (e.g. with the official `tree-sitter/go-tree-sitter` module when it stabilises)
without touching the domain or public API.

## Consequences

**Positive:**
- Single module addition enables 7 languages immediately (Go, Python, JS, TS, Java, Ruby, Rust).
- Adding a new language = one `mustRegister` call + one `.scm` file.
- Queries are readable and editable outside Go code.
- Tree-sitter is error-tolerant: partial or syntactically invalid files still yield useful results.

**Negative:**
- Requires CGO (`CGO_ENABLED=1` and a C compiler at build time).
  Cross-compilation is constrained to CGO-enabled targets.
  The `ubuntu-latest` CI runner already has GCC; no CI change is required.
- Binary size increases by approximately 1–2 MB per bundled grammar.
- Tree-sitter rows and columns are 0-indexed; callers must convert to 1-indexed line numbers
  (handled internally in `nodeLines()`).

**Follow-on decisions tracked separately:**
- Migrating to the official `tree-sitter/go-tree-sitter` module (if/when it reaches stability).
- Adding method-level classification for Python and Rust (currently all `def`/`fn` are `function`).
