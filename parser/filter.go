package parser

import "strings"

// Filter specifies criteria to narrow down symbols from an ExtractResult.
// Both criteria are combined with AND — a symbol must satisfy all non-zero fields.
type Filter struct {
	// Kinds restricts results to symbols of the given kinds.
	// Empty means all kinds are accepted.
	Kinds []SymbolKind
	// NameContains filters symbols whose Name contains this substring (case-insensitive).
	// Empty string matches all names.
	NameContains string
}

// Apply returns a new ExtractResult containing only symbols that match f.
// Language metadata is preserved unchanged.
// Example:
//
//	fns := parser.Filter{Kinds: []parser.SymbolKind{parser.SymbolFunction},
//	                     NameContains: "xpto"}.Apply(result)
func (f Filter) Apply(result ExtractResult) ExtractResult {
	filtered := make([]Symbol, 0, len(result.Symbols))
	for _, s := range result.Symbols {
		if f.matches(s) {
			filtered = append(filtered, s)
		}
	}
	return ExtractResult{FilePath: result.FilePath, Language: result.Language, Symbols: filtered, Comments: result.Comments}
}

func (f Filter) matches(s Symbol) bool {
	if len(f.Kinds) > 0 && !f.kindMatches(s.Kind) {
		return false
	}
	if f.NameContains != "" && !strings.Contains(
		strings.ToLower(s.Name),
		strings.ToLower(f.NameContains),
	) {
		return false
	}
	return true
}

func (f Filter) kindMatches(kind SymbolKind) bool {
	for _, k := range f.Kinds {
		if k == kind {
			return true
		}
	}
	return false
}
