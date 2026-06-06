package parser_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/eltu/idx-lib/parser"
)

func makeResult(syms ...parser.Symbol) parser.ExtractResult {
	return parser.ExtractResult{
		Language: parser.Language{Name: "go", Extension: ".go"},
		Symbols:  syms,
	}
}

func makeSymbol(name string, kind parser.SymbolKind) parser.Symbol {
	return parser.Symbol{Name: name, Kind: kind, StartLine: 1, EndLine: 5}
}

func TestFilter_Apply_ReturnsAllWhenBothCriteriaAreEmpty(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("Foo", parser.SymbolFunction),
		makeSymbol("Bar", parser.SymbolClass),
	)

	// Act
	got := parser.Filter{}.Apply(result)

	// Assert
	assert.Len(t, got.Symbols, 2)
}

func TestFilter_Apply_ReturnsOnlyMatchingKind(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("Foo", parser.SymbolFunction),
		makeSymbol("Bar", parser.SymbolClass),
		makeSymbol("Baz", parser.SymbolStruct),
	)

	// Act
	got := parser.Filter{Kinds: []parser.SymbolKind{parser.SymbolFunction}}.Apply(result)

	// Assert
	assert.Len(t, got.Symbols, 1)
	assert.Equal(t, "Foo", got.Symbols[0].Name)
}

func TestFilter_Apply_ReturnsOnlyMatchingName(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("getUserById", parser.SymbolFunction),
		makeSymbol("createOrder", parser.SymbolFunction),
		makeSymbol("getProductList", parser.SymbolFunction),
	)

	// Act
	got := parser.Filter{NameContains: "get"}.Apply(result)

	// Assert
	assert.Len(t, got.Symbols, 2)
}

func TestFilter_Apply_AppliesBothCriteriaWithAND(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("getUserById", parser.SymbolFunction),
		makeSymbol("UserRepository", parser.SymbolClass),
		makeSymbol("createOrder", parser.SymbolFunction),
	)

	// Act
	got := parser.Filter{
		Kinds:        []parser.SymbolKind{parser.SymbolFunction},
		NameContains: "User",
	}.Apply(result)

	// Assert
	assert.Len(t, got.Symbols, 1)
	assert.Equal(t, "getUserById", got.Symbols[0].Name)
}

func TestFilter_Apply_IsCaseInsensitiveForName(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("UserService", parser.SymbolClass),
		makeSymbol("productHandler", parser.SymbolFunction),
	)

	tests := []string{"user", "USER", "User", "uSeR"}

	for _, term := range tests {
		term := term
		t.Run(term, func(t *testing.T) {
			t.Parallel()

			got := parser.Filter{NameContains: term}.Apply(result)

			assert.Len(t, got.Symbols, 1)
			assert.Equal(t, "UserService", got.Symbols[0].Name)
		})
	}
}

func TestFilter_Apply_PreservesCommentsInResult(t *testing.T) {
	t.Parallel()

	// Arrange
	comment := parser.Comment{Content: "doc", StartLine: 1, EndLine: 1}
	result := makeResult(makeSymbol("Foo", parser.SymbolFunction))
	result.Comments = []parser.Comment{comment}

	// Act
	got := parser.Filter{Kinds: []parser.SymbolKind{parser.SymbolClass}}.Apply(result)

	// Assert
	assert.Empty(t, got.Symbols)
	assert.Equal(t, result.Comments, got.Comments)
}

func TestFilter_Apply_PreservesLanguageInResult(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(makeSymbol("Foo", parser.SymbolFunction))

	// Act
	got := parser.Filter{Kinds: []parser.SymbolKind{parser.SymbolClass}}.Apply(result)

	// Assert
	assert.Equal(t, result.Language, got.Language)
	assert.Empty(t, got.Symbols)
}

func TestFilter_Apply_AcceptsMultipleKinds(t *testing.T) {
	t.Parallel()

	// Arrange
	result := makeResult(
		makeSymbol("Foo", parser.SymbolFunction),
		makeSymbol("Bar", parser.SymbolClass),
		makeSymbol("Baz", parser.SymbolStruct),
		makeSymbol("Qux", parser.SymbolEnum),
	)

	// Act
	got := parser.Filter{
		Kinds: []parser.SymbolKind{parser.SymbolFunction, parser.SymbolStruct},
	}.Apply(result)

	// Assert
	assert.Len(t, got.Symbols, 2)
}

func TestFilter_Apply_AllKindsCoveredByConstant(t *testing.T) {
	t.Parallel()

	allKinds := []parser.SymbolKind{
		parser.SymbolFunction,
		parser.SymbolMethod,
		parser.SymbolClass,
		parser.SymbolStruct,
		parser.SymbolInterface,
		parser.SymbolEnum,
		parser.SymbolModule,
	}

	result := parser.ExtractResult{}
	for _, k := range allKinds {
		result.Symbols = append(result.Symbols, makeSymbol("x", k))
	}

	for _, k := range allKinds {
		k := k
		t.Run(string(k), func(t *testing.T) {
			t.Parallel()

			got := parser.Filter{Kinds: []parser.SymbolKind{k}}.Apply(result)

			assert.Len(t, got.Symbols, 1)
			assert.Equal(t, k, got.Symbols[0].Kind)
		})
	}
}
