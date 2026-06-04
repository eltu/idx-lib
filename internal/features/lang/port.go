package lang

// Detector identifies the programming language of a SourceFile.
// Example:
//
//	id := d.Detect(file)
type Detector interface {
	Detect(file SourceFile) ID
}

// Tokenizer breaks source code into a flat sequence of RawTokens.
// Example:
//
//	tokens, err := t.Tokenize(file)
type Tokenizer interface {
	Tokenize(file SourceFile) ([]RawToken, error)
}
