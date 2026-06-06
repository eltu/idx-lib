package parser

// Parser parses raw source code into a structured Result.
// Example:
//
//	p := somepkg.NewParser()
//	result, err := p.Parse(src)
type Parser interface {
	Parse(src []byte) (Result, error)
}

// SymbolExtractor extracts named constructs from source code with their line ranges.
// Example:
//
//	e := somepkg.NewSymbolExtractor()
//	result, err := e.Extract(src, ".go")
type SymbolExtractor interface {
	Extract(src []byte, ext string) (ExtractResult, error)
}
