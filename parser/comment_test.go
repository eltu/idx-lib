package parser

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCleanCommentBody_LineCommentWithContent_ReturnsStrippedBody(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"Go line", "// Constants & iota", "Constants & iota"},
		{"Python hash", "# frozen_string_literal: true", "frozen_string_literal: true"},
		{"Ruby hash", "# load_config loads YAML", "load_config loads YAML"},
		{"Rust doc", "/// Rust doc comment", "Rust doc comment"},
		{"Rust inner doc", "//! crate-level inner doc", "crate-level inner doc"},
		{"Go build tag", "//go:build ignore", "go:build ignore"},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Equal(t, tc.want, cleanCommentBody(tc.input))
		})
	}
}

func TestCleanCommentBody_DecorativeLineComment_ReturnsEmpty(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
	}{
		{"Go dash separator", "// -------------------------------------------------------------------------- //"},
		{"Python dash separator", "# --------------------------------------------------------------------------- #"},
		{"Go empty comment", "//"},
		{"Python empty comment", "#"},
		{"Go equals separator", "// ====="},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Empty(t, cleanCommentBody(tc.input))
		})
	}
}

func TestCleanCommentBody_BlockCommentSingleLine_ReturnsStrippedBody(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"simple block", "/* block */", "block"},
		{"multi-word block", "/* hello world */", "hello world"},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Equal(t, tc.want, cleanCommentBody(tc.input))
		})
	}
}

func TestCleanCommentBody_BlockCommentMultiLine_JoinsSemanticLines(t *testing.T) {
	t.Parallel()

	// Arrange
	input := "/**\n * Description of the class\n * @param x value\n */"

	// Act
	got := cleanCommentBody(input)

	// Assert
	assert.Equal(t, "Description of the class\n@param x value", got)
}

func TestCleanCommentBody_BlockCommentAllDecorative_ReturnsEmpty(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
	}{
		{"inline dashes", "/* ----- */"},
		{"multiline dashes", "/**\n * ----\n */"},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Empty(t, cleanCommentBody(tc.input))
		})
	}
}

func TestIsDecorativeLine_DecorativeCharsOnly_ReturnsTrue(t *testing.T) {
	t.Parallel()

	cases := []string{"", "-----", "=====", "* * * *", "--- //", "# ---"}

	for _, c := range cases {
		c := c
		t.Run(c, func(t *testing.T) {
			t.Parallel()
			assert.True(t, isDecorativeLine(c))
		})
	}
}

func TestIsDecorativeLine_ContainsSemanticChar_ReturnsFalse(t *testing.T) {
	t.Parallel()

	cases := []string{"Constants", "hello", "@param", "go:build"}

	for _, c := range cases {
		c := c
		t.Run(c, func(t *testing.T) {
			t.Parallel()
			assert.False(t, isDecorativeLine(c))
		})
	}
}

func TestRemoveLineMarker_KnownPrefixes_StripsLongestMatchFirst(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"empty comment", "//", ""},
		{"Go line with space", "// foo", " foo"},
		{"Rust doc — must not leave /", "///foo", "foo"},
		{"Rust inner — must not leave !", "//! bar", " bar"},
		{"Python hash", "# baz", " baz"},
		{"no marker passthrough", "neither", "neither"},
		{"Rust doc empty", "///", ""},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Equal(t, tc.want, removeLineMarker(tc.input))
		})
	}
}

func TestStripBlockInteriorLine_AsteriskPrefixes_StripsMarker(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"star space prefix", " * foo", "foo"},
		{"bare star", " *", ""},
		{"double star", " **", ""},
		{"plain text", "plain text", "plain text"},
		{"only spaces", "   ", ""},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Equal(t, tc.want, stripBlockInteriorLine(tc.input))
		})
	}
}

func TestGroupConsecutiveComments_AdjacentLines_MergesIntoSingleEntry(t *testing.T) {
	t.Parallel()

	// Arrange
	comments := []Comment{
		{Context: "line one", StartLine: 1, EndLine: 1},
		{Context: "line two", StartLine: 2, EndLine: 2},
		{Context: "line three", StartLine: 3, EndLine: 3},
	}

	// Act
	got := groupConsecutiveComments(comments)

	// Assert
	require.Len(t, got, 1)
	assert.Equal(t, "line one\nline two\nline three", got[0].Context)
	assert.Equal(t, 1, got[0].StartLine)
	assert.Equal(t, 3, got[0].EndLine)
}

func TestGroupConsecutiveComments_GapBetweenLines_KeepsSeparate(t *testing.T) {
	t.Parallel()

	// Arrange
	comments := []Comment{
		{Context: "first", StartLine: 1, EndLine: 1},
		{Context: "second", StartLine: 5, EndLine: 5},
	}

	// Act
	got := groupConsecutiveComments(comments)

	// Assert
	require.Len(t, got, 2)
	assert.Equal(t, "first", got[0].Context)
	assert.Equal(t, "second", got[1].Context)
}

func TestGroupConsecutiveComments_EmptySlice_ReturnsEmpty(t *testing.T) {
	t.Parallel()

	got := groupConsecutiveComments([]Comment{})

	assert.Empty(t, got)
}

func TestGroupConsecutiveComments_MixedAdjacentAndGap_GroupsCorrectly(t *testing.T) {
	t.Parallel()

	// Arrange — group A (lines 1-2), gap, group B (lines 5-6), solo (line 10)
	comments := []Comment{
		{Context: "a1", StartLine: 1, EndLine: 1},
		{Context: "a2", StartLine: 2, EndLine: 2},
		{Context: "b1", StartLine: 5, EndLine: 5},
		{Context: "b2", StartLine: 6, EndLine: 6},
		{Context: "solo", StartLine: 10, EndLine: 10},
	}

	// Act
	got := groupConsecutiveComments(comments)

	// Assert
	require.Len(t, got, 3)
	assert.Equal(t, "a1\na2", got[0].Context)
	assert.Equal(t, 1, got[0].StartLine)
	assert.Equal(t, 2, got[0].EndLine)
	assert.Equal(t, "b1\nb2", got[1].Context)
	assert.Equal(t, "solo", got[2].Context)
}

func TestStripBlockComment_MultiLineJavadoc_ExtractsBodyLines(t *testing.T) {
	t.Parallel()

	// Arrange — representative Javadoc header
	input := "/**\n * sample.java — comprehensive Java syntax fixture for parser testing.\n * Covers: classes, interfaces, generics, streams.\n */"

	// Act
	got := stripBlockComment(input)

	// Assert
	assert.Contains(t, got, "sample.java")
	assert.Contains(t, got, "Covers: classes")
}
