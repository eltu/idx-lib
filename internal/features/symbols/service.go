package symbols

import (
	"fmt"

	"github.com/eltu/idx-lib/internal/features/lang"
)

// ExtractService orchestrates language detection and symbol extraction.
type ExtractService struct {
	detector  lang.Detector
	extractor Extractor
}

// NewExtractService creates an ExtractService with the given Detector and Extractor.
// Example:
//
//	svc := symbols.NewExtractService(detector, extractor)
func NewExtractService(detector lang.Detector, extractor Extractor) *ExtractService {
	return &ExtractService{detector: detector, extractor: extractor}
}

// Extract detects the language and extracts symbols from file.
// Returns an empty result (no error) for unsupported languages.
// Example:
//
//	result, err := svc.Extract(lang.SourceFile{Content: src, Extension: ".go"})
func (s *ExtractService) Extract(file lang.SourceFile) (ExtractResult, error) {
	if len(file.Content) == 0 {
		return ExtractResult{}, fmt.Errorf("source content must not be empty")
	}
	langID := s.detector.Detect(file)
	syms, comments, err := s.extractor.Extract(file, langID)
	if err != nil {
		return ExtractResult{}, fmt.Errorf("extract %q: %w", string(langID), err)
	}
	return ExtractResult{
		LanguageID: string(langID),
		Extension:  file.Extension,
		Symbols:    syms,
		Comments:   comments,
	}, nil
}
