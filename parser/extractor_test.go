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
	result, err := e.Extract(src, "sample.go")

	// Assert
	require.NoError(t, err)
	assert.NotEmpty(t, result.Symbols)
	assert.Equal(t, "go", result.Language.Name)
}

func TestNewSymbolExtractor_Extract_PopulatesFilePath(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := fixtures.MustReadFile("go")
	const path = "/repo/internal/features/auth/service.go"

	// Act
	result, err := e.Extract(src, path)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, path, result.FilePath)
}

func TestNewSymbolExtractor_Extract_ResultIsJSONSerializable(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := fixtures.MustReadFile("go")

	// Act
	result, err := e.Extract(src, "sample.go")
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
	result, err := e.Extract([]byte("anything"), "sample.dart")

	// Assert
	require.NoError(t, err)
	assert.Empty(t, result.Symbols)
}

func TestNewSymbolExtractor_Extract_ReturnsCommentsForGoSource(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := []byte("// top-level doc\npackage foo\n\n/* block */\n")

	// Act
	result, err := e.Extract(src, "sample.go")

	// Assert
	require.NoError(t, err)
	assert.NotEmpty(t, result.Comments)

	contents := make([]string, len(result.Comments))
	for i, c := range result.Comments {
		contents[i] = c.Context
		assert.GreaterOrEqual(t, c.StartLine, 1)
		assert.LessOrEqual(t, c.StartLine, c.EndLine)
	}
	assert.Contains(t, contents, "top-level doc")
	assert.Contains(t, contents, "block")
}

func TestNewSymbolExtractor_Extract_ResultIsJSONSerializableWithComments(t *testing.T) {
	t.Parallel()

	// Arrange
	e := parser.NewSymbolExtractor()
	src := fixtures.MustReadFile("go")

	// Act
	result, err := e.Extract(src, "sample.go")
	require.NoError(t, err)

	// Assert — comments field present and each entry has expected keys
	data, err := json.Marshal(result)
	require.NoError(t, err)

	var decoded map[string]any
	require.NoError(t, json.Unmarshal(data, &decoded))

	coms, ok := decoded["comments"].([]any)
	require.True(t, ok, "comments must be an array")
	assert.NotEmpty(t, coms)

	for _, raw := range coms {
		entry := raw.(map[string]any)
		assert.Contains(t, entry, "context")
		assert.Contains(t, entry, "start_line")
		assert.Contains(t, entry, "end_line")
		assert.NotEmpty(t, entry["context"], "decorative comment must not appear in output")
	}
}

func TestNewSymbolExtractor_Extract_ExcludesDecorativeComments(t *testing.T) {
	t.Parallel()

	// Arrange — source with one semantic and one decorative comment
	e := parser.NewSymbolExtractor()
	src := []byte("// -------------------------------------------------------------------------- //\n// useful doc\npackage foo\n")

	// Act
	result, err := e.Extract(src, "sample.go")

	// Assert — only the semantic comment survives
	require.NoError(t, err)
	require.Len(t, result.Comments, 1)
	assert.Equal(t, "useful doc", result.Comments[0].Context)
}

func TestNewSymbolExtractor_Extract_GroupsConsecutiveComments(t *testing.T) {
	t.Parallel()

	// Arrange — three consecutive line comments followed by a gap then one more
	e := parser.NewSymbolExtractor()
	src := []byte("// line one\n// line two\n// line three\npackage foo\n\n// isolated\n")

	// Act
	result, err := e.Extract(src, "sample.go")

	// Assert
	require.NoError(t, err)
	require.Len(t, result.Comments, 2)

	group := result.Comments[0]
	assert.Equal(t, "line one\nline two\nline three", group.Context)
	assert.Equal(t, 1, group.StartLine)
	assert.Equal(t, 3, group.EndLine)

	isolated := result.Comments[1]
	assert.Equal(t, "isolated", isolated.Context)
	assert.Equal(t, isolated.StartLine, isolated.EndLine)
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
