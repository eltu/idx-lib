package lang

// ID is a canonical identifier for a programming language.
type ID string

const (
	Go         ID = "go"
	Python     ID = "python"
	JavaScript ID = "javascript"
	TypeScript ID = "typescript"
	Java       ID = "java"
	Ruby       ID = "ruby"
	Rust       ID = "rust"
	Unknown    ID = "unknown"
)

// SourceFile holds raw source code with optional file metadata.
type SourceFile struct {
	Content   []byte
	Extension string
}

// RawToken is an unclassified lexical unit from a tokenizer.
type RawToken struct {
	Value string
	Line  int
	Col   int
}

// ParseResult holds the output of the internal parse pipeline.
type ParseResult struct {
	LanguageID ID
	Tokens     []RawToken
}
