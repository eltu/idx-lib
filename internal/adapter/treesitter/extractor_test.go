package treesitter_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/eltu/idx-lib/internal/adapter/treesitter"
	"github.com/eltu/idx-lib/internal/features/lang"
	"github.com/eltu/idx-lib/internal/features/symbols"
	fixtures "github.com/eltu/idx-lib/testdata/fixtures"
)

func TestTreeSitterExtractor_Extract_ReturnsNilForUnknownLanguage(t *testing.T) {
	t.Parallel()

	// Arrange
	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	file := lang.SourceFile{Content: []byte("anything"), Extension: ".xyz"}

	// Act
	syms, comments, err := ext.Extract(file, lang.Unknown)

	// Assert
	require.NoError(t, err)
	assert.Nil(t, syms)
	assert.Nil(t, comments)
}

func TestTreeSitterExtractor_Extract_SymbolsHaveValidLineRanges(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		ext  string
		id   lang.ID
	}{
		{"Go", "go", lang.Go},
		{"Python", "py", lang.Python},
		{"JavaScript", "js", lang.JavaScript},
		{"TypeScript", "ts", lang.TypeScript},
		{"Java", "java", lang.Java},
		{"Ruby", "rb", lang.Ruby},
		{"Rust", "rs", lang.Rust},
	}

	ext := treesitter.NewExtractor(treesitter.NewRegistry())

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Arrange
			src := fixtures.MustReadFile(tc.ext)
			file := lang.SourceFile{Content: src, Extension: "." + tc.ext}

			// Act
			syms, comments, err := ext.Extract(file, tc.id)

			// Assert
			require.NoError(t, err)
			assert.NotEmpty(t, syms, "expected symbols for %s", tc.name)
			for _, s := range syms {
				assert.NotEmpty(t, s.Name, "symbol name must not be empty")
				assert.GreaterOrEqual(t, s.StartLine, 1, "StartLine must be ≥ 1")
				assert.LessOrEqual(t, s.StartLine, s.EndLine, "StartLine must be ≤ EndLine")
			}
			assert.NotEmpty(t, comments, "expected comments for %s", tc.name)
			for _, c := range comments {
				assert.NotEmpty(t, c.Text, "comment text must not be empty")
				assert.GreaterOrEqual(t, c.StartLine, 1, "comment StartLine must be ≥ 1")
				assert.LessOrEqual(t, c.StartLine, c.EndLine, "comment StartLine must be ≤ EndLine")
			}
		})
	}
}

func TestTreeSitterExtractor_Extract_ContainsExpectedGoSymbols(t *testing.T) {
	t.Parallel()

	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	src := fixtures.MustReadFile("go")

	// Act
	syms, _, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".go"}, lang.Go)

	// Assert
	require.NoError(t, err)

	tests := []struct {
		name string
		kind symbols.Kind
	}{
		{"NewUser", symbols.KindFunction},
		{"Sum", symbols.KindFunction},
		{"FanOut", symbols.KindFunction},
		{"safeExec", symbols.KindFunction},
		{"String", symbols.KindMethod},
		{"User", symbols.KindStruct},
		{"AppError", symbols.KindStruct},
		{"MemoryStore", symbols.KindStruct},
		{"Writer", symbols.KindInterface},
		{"Repository", symbols.KindInterface},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assertContainsSymbol(t, syms, tc.name, tc.kind)
		})
	}
}

func TestTreeSitterExtractor_Extract_ContainsExpectedPythonSymbols(t *testing.T) {
	t.Parallel()

	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	src := fixtures.MustReadFile("py")
	syms, _, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".py"}, lang.Python)

	require.NoError(t, err)

	tests := []struct {
		name string
		kind symbols.Kind
	}{
		{"retry", symbols.KindFunction},
		{"fibonacci", symbols.KindFunction},
		{"load_config", symbols.KindFunction},
		{"Animal", symbols.KindClass},
		{"Dog", symbols.KindClass},
		{"Config", symbols.KindClass},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assertContainsSymbol(t, syms, tc.name, tc.kind)
		})
	}
}

func TestTreeSitterExtractor_Extract_ContainsExpectedRustSymbols(t *testing.T) {
	t.Parallel()

	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	src := fixtures.MustReadFile("rs")
	syms, _, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".rs"}, lang.Rust)

	require.NoError(t, err)

	tests := []struct {
		name string
		kind symbols.Kind
	}{
		{"largest", symbols.KindFunction},
		{"fibonacci", symbols.KindFunction},
		{"main", symbols.KindFunction},
		{"User", symbols.KindStruct},
		{"Vec2", symbols.KindStruct},
		{"Status", symbols.KindEnum},
		{"AppError", symbols.KindEnum},
		{"Repository", symbols.KindInterface},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assertContainsSymbol(t, syms, tc.name, tc.kind)
		})
	}
}

func TestTreeSitterExtractor_Extract_ContainsExpectedJavaSymbols(t *testing.T) {
	t.Parallel()

	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	src := fixtures.MustReadFile("java")
	syms, _, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".java"}, lang.Java)

	require.NoError(t, err)

	tests := []struct {
		name string
		kind symbols.Kind
	}{
		{"StreamExamples", symbols.KindClass},
		{"AppException", symbols.KindClass},
		{"Repository", symbols.KindInterface},
		{"Status", symbols.KindEnum},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assertContainsSymbol(t, syms, tc.name, tc.kind)
		})
	}
}

func TestTreeSitterExtractor_Extract_ContainsExpectedRubySymbols(t *testing.T) {
	t.Parallel()

	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	src := fixtures.MustReadFile("rb")
	syms, _, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".rb"}, lang.Ruby)

	require.NoError(t, err)

	tests := []struct {
		name string
		kind symbols.Kind
	}{
		{"Animal", symbols.KindClass},
		{"Dog", symbols.KindClass},
		{"Stack", symbols.KindClass},
		{"Serializable", symbols.KindModule},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assertContainsSymbol(t, syms, tc.name, tc.kind)
		})
	}
}

func TestTreeSitterExtractor_Extract_CommentsHaveValidLineRangesAndText(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		ext  string
		id   lang.ID
	}{
		{"Go", "go", lang.Go},
		{"Python", "py", lang.Python},
		{"JavaScript", "js", lang.JavaScript},
		{"TypeScript", "ts", lang.TypeScript},
		{"Java", "java", lang.Java},
		{"Ruby", "rb", lang.Ruby},
		{"Rust", "rs", lang.Rust},
	}

	ext := treesitter.NewExtractor(treesitter.NewRegistry())

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Arrange
			src := fixtures.MustReadFile(tc.ext)
			file := lang.SourceFile{Content: src, Extension: "." + tc.ext}

			// Act
			_, comments, err := ext.Extract(file, tc.id)

			// Assert
			require.NoError(t, err)
			assert.NotEmpty(t, comments, "expected comments for %s", tc.name)
			for _, c := range comments {
				assert.NotEmpty(t, c.Text, "comment text must not be empty")
				assert.GreaterOrEqual(t, c.StartLine, 1, "StartLine must be ≥ 1")
				assert.LessOrEqual(t, c.StartLine, c.EndLine, "StartLine must be ≤ EndLine")
			}
		})
	}
}

func TestTreeSitterExtractor_Extract_GoCommentTextMatchesSource(t *testing.T) {
	t.Parallel()

	// Arrange
	src := []byte("// Package doc\npackage foo\n\n/* block */\n")
	ext := treesitter.NewExtractor(treesitter.NewRegistry())
	file := lang.SourceFile{Content: src, Extension: ".go"}

	// Act
	_, comments, err := ext.Extract(file, lang.Go)

	// Assert
	require.NoError(t, err)
	require.Len(t, comments, 2)
	assert.Equal(t, "// Package doc", comments[0].Text)
	assert.Equal(t, 1, comments[0].StartLine)
	assert.Equal(t, 1, comments[0].EndLine)
	assert.Equal(t, "/* block */", comments[1].Text)
	assert.Equal(t, 4, comments[1].StartLine)
	assert.Equal(t, 4, comments[1].EndLine)
}

// assertContainsSymbol fails the test if no symbol with the given name and kind exists.
func assertContainsSymbol(t *testing.T, syms []symbols.RawSymbol, name string, kind symbols.Kind) {
	t.Helper()
	for _, s := range syms {
		if s.Name == name && s.Kind == kind {
			return
		}
	}
	t.Errorf("symbol %q (%s) not found among %d extracted symbols", name, kind, len(syms))
}
