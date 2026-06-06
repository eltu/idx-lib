package symbols

import "github.com/eltu/idx-lib/internal/features/lang"

// Extractor extracts named symbols and comments from source for a given language.
// Example:
//
//	syms, comments, err := e.Extract(file, lang.Go)
type Extractor interface {
	Extract(file lang.SourceFile, langID lang.ID) ([]RawSymbol, []RawComment, error)
}
