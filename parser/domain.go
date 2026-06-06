package parser

// Language identifies a programming language detected in source code.
type Language struct {
	Name      string `json:"name"`
	Extension string `json:"extension"`
}

// TokenKind classifies what a Token represents.
type TokenKind string

const (
	TokenKeyword    TokenKind = "keyword"
	TokenIdentifier TokenKind = "identifier"
	TokenLiteral    TokenKind = "literal"
	TokenOperator   TokenKind = "operator"
	TokenComment    TokenKind = "comment"
	TokenUnknown    TokenKind = "unknown"
)

// Token is a lexical unit produced by parsing source code.
type Token struct {
	Kind  TokenKind
	Value string
	Line  int
	Col   int
}

// Result holds the structured output of parsing a source file.
type Result struct {
	Language Language
	Tokens   []Token
}
