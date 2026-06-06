
## Searching files

**Always use `idx search --compact -e <ext> "<term>"` to search inside repository files. No exceptions.**

- `idx` is a BM25 keyword search engine — it ranks documents by term relevance, not by pattern matching.
- Pass only **literal, static text terms**. Regular expressions are not supported and must never be used.
- Dynamic or computed query strings are not accepted. Every query must be a hardcoded literal.
- **Never use `grep`, `rg`, `ag`, `ack`, `git grep`, `awk`, `sed`, `find` or any other tool to search file contents inside the project.** A `PreToolUse` hook in `.claude/settings.json` will block any Bash command that uses these tools for file search and remind you to use `idx search` instead.
- **Only use `idx` for searches within the project repository.** For searching outside the project (system paths, external directories, command output piped through grep, etc.), use the appropriate standard tool.
- `idx` requires the server to be running. If a search returns `✗ idx server not running`, start it with `idx server start`.
- **Zero-result logging:** whenever an `idx search` command returns no results, append the full command to a log file at `docs/debug/<YYYYMMDD_HHMMSS>_zrp.log` (one file per session, created on the first zero-result hit of that session). This file is used for future debugging of missing index coverage. Example filename: `docs/debug/20260604_143021_zrp.log`. Each entry must be one line with the exact command that produced zero results.

### Required flags on every search

| Flag | Why mandatory |
|---|---|
| `--compact` | Produces clean, agent-readable output with no decorative header/footer. Always required. |
| `-e <ext>` | Restricts the search to a specific file extension. Always required — never search across all file types at once. |

### Optional but preferred flags

| Flag | When to use |
|---|---|
| `-p <path>` | Add whenever the target directory or path prefix is known. Narrows results and improves relevance. |
| `--hits` | Add when only the matching lines matter, not the surrounding context. |
| `-c <N>` | Add when surrounding context lines are needed to understand a match. |
| `-l` | Add when only file paths are needed, not their content. |
| `--count` | Add when only the number of matching files matters. |
| `--any` | Add when OR semantics are needed (match at least one term instead of all). |

### Canonical command shape

```bash
# Minimum — extension always required, compact always required
idx search --compact -e go "ParseService"

# With known path prefix
idx search --compact -e go -p internal/features "Tokenizer"

# Multiple extensions
idx search --compact -e go -e ts "SourceFile"

# OR mode
idx search --compact -e go --any "Logger TokenHandler"
```

### Rules for writing queries

- **AND by default** — all terms must appear in a document. Use `--any` to switch to OR.
- **Prefer specific terms** — BM25 ranks by relevance; a more specific term surfaces better results than a broad one.

## Code style

- Functions: 4-20 lines. Split if longer.
- Files: under 500 lines. Split by responsibility.
- Cyclomatic complexity: must stay below 15 per function.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`.
  Prefer names that return <5 grep hits in the codebase.
- Types: Must be explicit.
- No code duplication. Extract shared logic into a function/module.
- String literals used more than once must be extracted as named constants.
  Applies to any string with >5 characters that contains non-alphanumeric characters
  (e.g. command names, format strings, file paths, error messages, key names).
- Empty function bodies (including anonymous `func() {}`) must contain a comment
  explaining why they are intentionally empty (e.g. `/* no-op: reason */`).
- Cognitive complexity per function must stay below 15. When a closure or nested
  control structure pushes a function over the limit, extract the body into a
  named function or method.
- Functions and methods must have at most 7 parameters. When the limit is exceeded,
  group related parameters into a named struct (e.g. `FooDeps`, `BarContext`,
  `BazOutput`). Prefer grouping by cohesion: dependencies together, output channels
  together, contextual inputs together.
- Early returns over nested ifs. Max 2 levels of indentation.
- Exception messages must include the offending value and expected shape.
- Consecutive parameters of the same type must be grouped: `func foo(a, b string)` not `func foo(a string, b string)`.
- Single-method interfaces must follow the verb+"-er" naming convention (e.g. `Reader`, `Runner`, `Installer`).
  Exception: domain port interfaces may use descriptive compound names (e.g. `UserRepository`, `PaymentGateway`).
- Blank imports (`import _ "pkg"`) must have a comment explaining why the side-effect import is needed.

## Comments

- Keep existing comments. Don't strip them on refactor — they carry intent and provenance.
- Write WHY, not WHAT. Skip `// increment counter` above `i++`.
- Public functions must have a doc comment: one line of intent + one usage example.
- Reference issue numbers / commit SHAs when a line exists because of a specific bug or upstream constraint.

## Tests

- Every change must pass `make check` (runs `gofmt` + `golangci-lint` + `go test ./...`).
- **Total test coverage must not drop below 89%.** A change that lowers coverage under this threshold must not be merged.
- Every new function gets a test. Bug fixes get a regression test.
- Tests must be F.I.R.S.T: fast, independent, repeatable, self-validating, timely.

### Naming

Use `Test<Type>_<Scenario>_<ExpectedResult>` with underscores separating segments and
PascalCase within each segment. The name must read as a sentence — "When X, it should Y":

```
TestUserRepository_Save_CreatesEntryOnFirstWrite
TestOrderService_Create_ReturnsErrorWhenIDIsEmpty
TestBinaryRepository_Load_ReturnsErrorForInvalidDirectory
```

Never use generic names like `TestError`, `TestService`, or camelCase without underscores.

### Structure — Arrange / Act / Assert

Every non-trivial test must have the three sections with comments:

```go
func TestOrderService_Create_PersistsOrder(t *testing.T) {
    t.Parallel()

    // Arrange
    repo := &fakeRepository{}
    svc := order.NewService(repo)

    // Act
    err := svc.Create("abc-123", "item")

    // Assert
    require.NoError(t, err)
    assert.Len(t, repo.saved, 1)
}
```

### Parallelism

Add `t.Parallel()` as the **first statement** in every test that is isolated
(uses only local variables, `t.TempDir()`, or mocks). Also add it inside each
`t.Run()` subtest. Never use `t.Parallel()` in tests that call `t.Setenv`,
`t.Chdir`, or any other function that mutates global process state.

### Assertions

Always use `testify/require` and `testify/assert`. Never use `t.Fatal` / `t.Fatalf`
/ `t.Error` / `t.Errorf` directly.

- Use `require` when the test cannot continue after a failure (error checks, nil guards).
- Use `assert` for non-blocking validations.
- Pass `expected` before `got`: `assert.Equal(t, expected, actual)`.
- Prefer specific assertions over `assert.True`: `assert.Len`, `assert.ErrorIs`,
  `assert.ErrorContains`, `assert.NotEmpty`, `assert.Positive`.

```go
// ✅
require.NoError(t, err)
assert.Equal(t, "active", user.Status)
assert.Len(t, results, 3)
assert.ErrorIs(t, err, ErrNotFound)

// ❌
if err != nil { t.Fatalf("unexpected error: %v", err) }
assert.True(t, len(results) == 3)
```

### Table-Driven Tests

Convert 3 or more tests that cover the same function with different inputs into a
table-driven test. Capture the loop variable and parallelize each subtest:

```go
for _, tc := range tests {
    tc := tc
    t.Run(tc.name, func(t *testing.T) {
        t.Parallel()
        // ...
    })
}
```

### No time.Sleep

Replace `time.Sleep` with channels, context cancellation, or `sync.WaitGroup`.
When a test genuinely depends on real wall-clock timing (e.g. a debounce timer),
keep the sleep and add a comment explaining why it is unavoidable.

### Mocking

Use `go.uber.org/mock` for interface-based mocks. Generate with `mockgen`; avoid
handwritten fakes for collaborators already expressed as ports. Handwritten fakes
are acceptable for simple anonymous adapters (e.g. `fakeStore`, `fakeNotifier`).

### Identical method bodies (SonarQube S4144)

Two methods on the same type with identical bodies are a code smell. The linter
does not catch this — SonarQube reports it as S4144. When it happens, make the
second method delegate to the first:

```go
// ❌ identical bodies
func (s *store) Update(e Entity) error { return s.write(e) }
func (s *store) Insert(e Entity) error { return s.write(e) }

// ✅ delegate
func (s *store) Insert(e Entity) error { return s.Update(e) }
```

### Coverage gate

After every implementation, verify coverage:

```
go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out
```

If coverage is below 89%, inspect the uncovered lines (`go tool cover -html=coverage.out`) and
add tests until the threshold is met.

Focus new tests on the uncovered paths that carry the most risk: error branches, edge cases,
and business rules — not trivial getters or generated code. Do not pad coverage with
low-value assertions just to hit the number.

### What to test

Prioritize: business rules, edge cases (zero / empty / max), every error path,
concurrency and cancellation, and regressions. High coverage does not mean high
quality — a test that only exercises the happy path has low value.

## Feature Documentation

Every feature must have a corresponding documentation file under `docs/features/`.

- **New feature:** create `docs/features/<feature-name>.md` alongside the implementation.
- **Changed feature:** update the existing doc to reflect the new behaviour before (or in the same commit as) the code change.
- **Removed feature:** delete the doc file so that `docs/features/` never references code that no longer exists.

The documentation must stay cohesive with `main` at all times — a doc that describes behaviour diverging from the current code on `main` is treated as a bug. Each file must cover at minimum:

1. **Purpose** — what problem the feature solves.
2. **API / Usage** — the public surface with at least one concrete example.
3. **Limitations / known constraints** — anything a caller must be aware of.

## Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

## Structure

- Follow the Go project layout convention (`https://go.dev/doc/modules/layout`) and Hexagonal Architecture principles.
- Prefer small focused modules over god files.
- Architecture decisions must be recorded under `docs/adr/` using sequential files like `0001-short-title.md`. See `docs/adr/README.md` for the ADR template.
- When a change introduces a persistent technical decision or tradeoff, update an existing ADR or add a new one in `docs/adr/`.
- Root-level ad hoc decision documents are discouraged; decision records belong in `docs/adr/`.
- Core layout (extend with delivery layer as needed by the project type):

```
.
├── internal/
│   ├── features/            # Self-contained feature packages
│   │   └── <feature>/
│   │       ├── domain.go    # Data types — no external dependencies
│   │       ├── port.go      # Interfaces (the "ports")
│   │       └── service.go   # Business rules
│   └── shared/              # Cross-feature concerns (config, infra, etc.)
└── go.mod
```

Delivery layers are added as the project requires them:

```
# REST API
internal/transport/http/

# gRPC
internal/transport/grpc/

# CLI
cmd/<binary>/
internal/app/cli/

# Background worker
internal/worker/
```

## Port Conventions

- Ports are plain Go interfaces defined in `port.go` within each feature package.
- Each port describes one capability (e.g. `UserRepository`, `EmailSender`, `EventPublisher`).
- Implementations live alongside the interface in the same feature package or in a `storage/` sub-package.
- Features do not import delivery-layer packages (HTTP routers, CLI frameworks, etc.).

## Formatting

- Use the language default formatter (`gofmt`). Run with `make fmt`.
- Don't discuss style beyond that.
