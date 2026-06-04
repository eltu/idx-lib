
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

After every implementation, run `go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out`
and check the total coverage. If the result is **below 89%**, inspect the uncovered lines
(`go tool cover -html=coverage.out`) and add tests until the threshold is met.

Focus new tests on the uncovered paths that carry the most risk: error branches, edge cases,
and business rules — not trivial getters or generated code. Do not pad coverage with
low-value assertions just to hit the number.

### What to test

Prioritize: business rules, edge cases (zero / empty / max), every error path,
concurrency and cancellation, and regressions. High coverage does not mean high
quality — a test that only exercises the happy path has low value.

## Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

## Structure

- Follow the Go project layout convention (`https://go.dev/doc/modules/layout`) and Hexagonal Architecture principles.
- Prefer small focused modules over god files.
- Architecture decisions must be recorded under `docs/adr/` using sequential files like `0001-short-title.md`.
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

## Architecture Decisions

Record every significant technical decision in `docs/adr/` before or alongside the implementation.
See `docs/adr/README.md` for the ADR template.

## Formatting

- Use the language default formatter (`gofmt`). Run with `make fmt`.
- Don't discuss style beyond that.
