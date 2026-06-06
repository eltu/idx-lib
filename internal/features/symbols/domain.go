package symbols

// Kind classifies what a named symbol represents.
type Kind string

const (
	KindFunction  Kind = "function"
	KindMethod    Kind = "method"
	KindClass     Kind = "class"
	KindStruct    Kind = "struct"
	KindInterface Kind = "interface"
	KindEnum      Kind = "enum"
	KindModule    Kind = "module"
)

// RawSymbol is a named construct extracted from source code before public mapping.
type RawSymbol struct {
	Name      string
	Kind      Kind
	StartLine int
	EndLine   int
}

// ExtractResult holds the internal output of the symbol extraction pipeline.
type ExtractResult struct {
	LanguageID string
	Extension  string
	Symbols    []RawSymbol
}
