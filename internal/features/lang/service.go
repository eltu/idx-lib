package lang

import "fmt"

// ParseService orchestrates language detection and tokenization.
type ParseService struct {
	detector  Detector
	tokenizer Tokenizer
}

// NewParseService creates a ParseService with the given Detector and Tokenizer.
// Example:
//
//	svc := lang.NewParseService(detector, tokenizer)
func NewParseService(detector Detector, tokenizer Tokenizer) *ParseService {
	return &ParseService{detector: detector, tokenizer: tokenizer}
}

// Parse detects the language and tokenizes src, returning the combined result.
// Example:
//
//	result, err := svc.Parse(lang.SourceFile{Content: src, Extension: ".go"})
func (s *ParseService) Parse(file SourceFile) (ParseResult, error) {
	if len(file.Content) == 0 {
		return ParseResult{}, fmt.Errorf("source content must not be empty")
	}
	langID := s.detector.Detect(file)
	tokens, err := s.tokenizer.Tokenize(file)
	if err != nil {
		return ParseResult{}, fmt.Errorf("tokenize %q: %w", string(langID), err)
	}
	return ParseResult{LanguageID: langID, Tokens: tokens}, nil
}
