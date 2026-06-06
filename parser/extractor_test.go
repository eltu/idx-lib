package parser_test

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/eltu/idx-lib/parser"
	fixtures "github.com/eltu/idx-lib/testdata/fixtures"
)

func TestNewSymbolExtractor_Extract_ReturnsSymbolsForGoSource(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := fixtures.MustReadFile("go")

	// Act
	result, err := e.Extract(src, ".go")

	// Assert
	require.NoError(t, err)
	assert.NotEmpty(t, result.Symbols)
	assert.Equal(t, "go", result.Language.Name)
}

func TestNewSymbolExtractor_Extract_ResultIsJSONSerializable(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := fixtures.MustReadFile("go")

	// Act
	result, err := e.Extract(src, ".go")
	require.NoError(t, err)

	// Assert — result must marshal to valid JSON with expected fields
	data, err := json.Marshal(result)
	require.NoError(t, err)

	var decoded map[string]any
	require.NoError(t, json.Unmarshal(data, &decoded))

	syms, ok := decoded["symbols"].([]any)
	require.True(t, ok, "symbols must be an array")
	assert.NotEmpty(t, syms)

	first := syms[0].(map[string]any)
	assert.Contains(t, first, "name")
	assert.Contains(t, first, "kind")
	assert.Contains(t, first, "start_line")
	assert.Contains(t, first, "end_line")
}

func TestNewSymbolExtractor_Extract_ReturnsEmptyForUnsupportedExtension(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()

	// Act
	result, err := e.Extract([]byte("anything"), ".dart")

	// Assert
	require.NoError(t, err)
	assert.Empty(t, result.Symbols)
}

func TestNewSymbolExtractor_Extract_ReturnsErrorWhenContentIsEmpty(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()

	// Act
	_, err := e.Extract([]byte{}, ".go")

	// Assert
	require.Error(t, err)
	assert.ErrorContains(t, err, "must not be empty")
}
