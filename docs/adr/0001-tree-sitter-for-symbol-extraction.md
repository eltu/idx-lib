# 0001 — Use tree-sitter for multi-language symbol extraction

**Status:** Accepted
**Date:** 2026-06-05
**Updated:** 2026-07-06 — migrated from `smacker/go-tree-sitter` to the official
`tree-sitter/go-tree-sitter` module (see Decision and Consequences below).

## Context

idx-lib must extract named constructs (functions, classes, structs, interfaces, enums, modules)
from source files written in multiple programming languages, producing structured output
suitable for indexing in a BM25 search engine.

Three approaches were considered:

1. **Regex-based matching** — simple to implement but fragile: fails on nested constructs,
   multiline declarations, and comments that contain keyword-like text.

2. **Per-language AST libraries** (`go/ast`, `pythonparser`, `java-parser`, etc.) — accurate
   but requires one dependency per language, each with its own API surface to wrap.

3. **Tree-sitter** — single family of dependencies that bundles grammars for 15+ languages.
   Uses a declarative S-expression query language that is uniform across languages. Initially
   adopted via the unofficial `github.com/smacker/go-tree-sitter` binding; migrated to the
   official `github.com/tree-sitter/go-tree-sitter` module plus per-language grammar packages
   (`github.com/tree-sitter/tree-sitter-go`, `-java`, `-javascript`, `-python`, `-ruby`, `-rust`,
   `-typescript`) once that module reached a stable v0.25.0 release.

## Decision

Use `github.com/tree-sitter/go-tree-sitter` (the official binding maintained by the
tree-sitter project), with one grammar package per supported language. It covers all target
languages, produces accurate parse trees even for syntactically incomplete code (tree-sitter
is error-tolerant by design), and allows adding a new language by registering one entry in the
`Registry` plus one `.scm` query file — no Go code changes required for the extraction logic.

The library is wrapped behind the `symbols.Extractor` port, so the tree-sitter implementation
can be replaced again in the future without touching the domain or public API.

## Consequences

**Positive:**
- Single module addition enables 7 languages immediately (Go, Python, JS, TS, Java, Ruby, Rust).
- Adding a new language = one `mustRegister` call + one `.scm` file.
- Queries are readable and editable outside Go code.
- Tree-sitter is error-tolerant: partial or syntactically invalid files still yield useful results.

**Negative:**
- Requires CGO (`CGO_ENABLED=1` and a C compiler at build time). This is true of both the
  unofficial and the official binding — the official module is also a CGo wrapper around the
  C tree-sitter runtime, not a pure-Go implementation. Cross-compilation is constrained to
  CGO-enabled targets. The `ubuntu-latest` CI runner already has GCC; no CI change is required.
- Binary size increases by approximately 1–2 MB per bundled grammar.
- Tree-sitter rows and columns are 0-indexed; callers must convert to 1-indexed line numbers
  (handled internally in `nodeLines()`).

**Follow-on decisions tracked separately:**
- Adding method-level classification for Python and Rust (currently all `def`/`fn` are `function`).
