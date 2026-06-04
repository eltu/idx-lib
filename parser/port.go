package parser

// Parser parses raw source code into a structured Result.
// Example:
//
//	p := somepkg.NewParser()
//	result, err := p.Parse(src)
type Parser interface {
	Parse(src []byte) (Result, error)
}
