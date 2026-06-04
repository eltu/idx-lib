package lang_test

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/eltu/idx-lib/internal/features/lang"
)

func TestParseService_Parse_ReturnsTokensForValidSource(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("package main"), Extension: ".go"}
	detector := &fakeDetector{langID: lang.Go}
	tokenizer := &fakeTokenizer{tokens: []lang.RawToken{{Value: "package", Line: 1, Col: 1}}}
	svc := lang.NewParseService(detector, tokenizer)

	// Act
	result, err := svc.Parse(file)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, lang.Go, result.LanguageID)
	assert.Len(t, result.Tokens, 1)
}

func TestParseService_Parse_ReturnsErrorWhenContentIsEmpty(t *testing.T) {
	t.Parallel()

	// Arrange
	svc := lang.NewParseService(&fakeDetector{}, &fakeTokenizer{})

	// Act
	_, err := svc.Parse(lang.SourceFile{})

	// Assert
	require.Error(t, err)
	assert.ErrorContains(t, err, "source content must not be empty")
}

func TestParseService_Parse_ReturnsErrorWhenTokenizerFails(t *testing.T) {
	t.Parallel()

	// Arrange
	file := lang.SourceFile{Content: []byte("???"), Extension: ".unknown"}
	tokenizer := &fakeTokenizer{err: errors.New("unsupported syntax")}
	svc := lang.NewParseService(&fakeDetector{langID: lang.Unknown}, tokenizer)

	// Act
	_, err := svc.Parse(file)

	// Assert
	require.Error(t, err)
	assert.ErrorContains(t, err, "unsupported syntax")
}

type fakeDetector struct{ langID lang.ID }

func (f *fakeDetector) Detect(_ lang.SourceFile) lang.ID { return f.langID }

type fakeTokenizer struct {
	tokens []lang.RawToken
	err    error
}

func (f *fakeTokenizer) Tokenize(_ lang.SourceFile) ([]lang.RawToken, error) {
	return f.tokens, f.err
}
