package symbols_test

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/eltu/idx-lib/internal/features/lang"
	"github.com/eltu/idx-lib/internal/features/symbols"
)

func TestExtractService_Extract_ReturnsSymbolsForValidSource(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("func Foo() {}"), Extension: ".go"}
	sym := symbols.RawSymbol{Name: "Foo", Kind: symbols.KindFunction, StartLine: 1, EndLine: 1}
	svc := symbols.NewExtractService(
		&fakeDetector{id: lang.Go},
		&fakeExtractor{syms: []symbols.RawSymbol{sym}},
	)

	// Act
	result, err := svc.Extract(file)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, string(lang.Go), result.LanguageID)
	assert.Equal(t, ".go", result.Extension)
	assert.Len(t, result.Symbols, 1)
	assert.Equal(t, sym, result.Symbols[0])
}

func TestExtractService_Extract_ReturnsErrorWhenContentIsEmpty(t *testing.T) {
	t.Parallel()

	// Arrange
	svc := symbols.NewExtractService(&fakeDetector{}, &fakeExtractor{})

	// Act
	_, err := svc.Extract(lang.SourceFile{})

	// Assert
	require.Error(t, err)
	assert.ErrorContains(t, err, "source content must not be empty")
}

func TestExtractService_Extract_ReturnsEmptyForUnknownLanguage(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("???"), Extension: ".xyz"}
	svc := symbols.NewExtractService(
		&fakeDetector{id: lang.Unknown},
		&fakeExtractor{syms: nil},
	)

	// Act
	result, err := svc.Extract(file)

	// Assert
	require.NoError(t, err)
	assert.Empty(t, result.Symbols)
}

func TestExtractService_Extract_ReturnsErrorWhenExtractorFails(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("func Broken()"), Extension: ".go"}
	svc := symbols.NewExtractService(
		&fakeDetector{id: lang.Go},
		&fakeExtractor{err: errors.New("parse failure")},
	)

	// Act
	_, err := svc.Extract(file)

	// Assert
	require.Error(t, err)
	assert.ErrorContains(t, err, "parse failure")
}

func TestExtractService_Extract_ForwardsExtensionToResult(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("x = 1"), Extension: ".py"}
	svc := symbols.NewExtractService(
		&fakeDetector{id: lang.Python},
		&fakeExtractor{},
	)

	// Act
	result, err := svc.Extract(file)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, ".py", result.Extension)
}

// fakeDetector is a test double for lang.Detector.
type fakeDetector struct{ id lang.ID }

func (f *fakeDetector) Detect(_ lang.SourceFile) lang.ID { return f.id }

// fakeExtractor is a test double for symbols.Extractor.
type fakeExtractor struct {
	syms []symbols.RawSymbol
	err  error
}

func (f *fakeExtractor) Extract(_ lang.SourceFile, _ lang.ID) ([]symbols.RawSymbol, error) {
	return f.syms, f.err
}
