package parser

import (
	"github.com/eltu/idx-lib/internal/adapter/treesitter"
	"github.com/eltu/idx-lib/internal/features/lang"
	"github.com/eltu/idx-lib/internal/features/symbols"
)

// NewSymbolExtractor creates a fully wired SymbolExtractor backed by tree-sitter.
// Supports Go, Python, JavaScript, TypeScript, Java, Ruby, and Rust.
// Example:
//
//	e := parser.NewSymbolExtractor()
//	result, err := e.Extract(src, ".go")
func NewSymbolExtractor() SymbolExtractor {
	reg := treesitter.NewRegistry()
	det := treesitter.NewExtensionDetector()
	ext := treesitter.NewExtractor(reg)
	svc := symbols.NewExtractService(det, ext)
	return &symbolExtractorAdapter{svc: svc}
}

type symbolExtractorAdapter struct {
	svc *symbols.ExtractService
}

func (a *symbolExtractorAdapter) Extract(src []byte, ext string) (ExtractResult, error) {
	file := lang.SourceFile{Content: src, Extension: ext}
	internal, err := a.svc.Extract(file)
	if err != nil {
		return ExtractResult{}, err
	}
	return mapExtractResult(internal), nil
}

func mapExtractResult(r symbols.ExtractResult) ExtractResult {
	syms := make([]Symbol, len(r.Symbols))
	for i, s := range r.Symbols {
		syms[i] = mapSymbol(s)
	}
	return ExtractResult{
		Language: Language{Name: r.LanguageID, Extension: r.Extension},
		Symbols:  syms,
	}
}

func mapSymbol(s symbols.RawSymbol) Symbol {
	return Symbol{
		Name:      s.Name,
		Kind:      SymbolKind(s.Kind),
		StartLine: s.StartLine,
		EndLine:   s.EndLine,
	}
}
