package parser

// SymbolKind classifies what a named construct represents.
type SymbolKind string

const (
	SymbolFunction  SymbolKind = "function"
	SymbolMethod    SymbolKind = "method"
	SymbolClass     SymbolKind = "class"
	SymbolStruct    SymbolKind = "struct"
	SymbolInterface SymbolKind = "interface"
	SymbolEnum      SymbolKind = "enum"
	SymbolModule    SymbolKind = "module"
)

// Symbol is a named construct extracted from source code with its line range.
type Symbol struct {
	Name      string     `json:"name"`
	Kind      SymbolKind `json:"kind"`
	StartLine int        `json:"start_line"`
	EndLine   int        `json:"end_line"`
}

// Comment is a comment node extracted from source code with its line range.
// Context holds the normalized text with delimiters stripped; consecutive comment
// lines are grouped into a single entry joined by newlines.
type Comment struct {
	Context   string `json:"context"`
	StartLine int    `json:"start_line"`
	EndLine   int    `json:"end_line"`
}

// ExtractResult holds the structured output of symbol extraction.
type ExtractResult struct {
	Language Language  `json:"language"`
	Symbols  []Symbol  `json:"symbols"`
	Comments []Comment `json:"comments"`
}
