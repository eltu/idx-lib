package treesitter

import (
	"context"
	"fmt"
	"strings"

	sitter "github.com/smacker/go-tree-sitter"

	"github.com/eltu/idx-lib/internal/features/lang"
	"github.com/eltu/idx-lib/internal/features/symbols"
)

const (
	captureName    = "name"
	capturePrefix  = "definition."
	captureComment = "comment"
)

// Extractor extracts named symbols from source using tree-sitter.
type Extractor struct {
	registry *Registry
}

// NewExtractor creates an Extractor backed by the given Registry.
// Example:
//
//	ext := treesitter.NewExtractor(treesitter.NewRegistry())
func NewExtractor(registry *Registry) *Extractor {
	return &Extractor{registry: registry}
}

// Extract parses file using the grammar for langID and returns all named symbols and comments.
// Returns nil slices (no error) for unsupported languages.
// Example:
//
//	syms, comments, err := ext.Extract(lang.SourceFile{Content: src, Extension: ".go"}, lang.Go)
func (e *Extractor) Extract(file lang.SourceFile, langID lang.ID) ([]symbols.RawSymbol, []symbols.RawComment, error) {
	cfg, ok := e.registry.Config(langID)
	if !ok {
		return nil, nil, nil
	}
	root, err := sitter.ParseCtx(context.Background(), file.Content, cfg.grammar)
	if err != nil {
		return nil, nil, fmt.Errorf("parse %q: %w", langID, err)
	}
	syms := collectSymbols(cfg.query, root, file.Content)
	comments := collectComments(cfg.commentQuery, root, file.Content)
	return syms, comments, nil
}

func collectSymbols(q *sitter.Query, root *sitter.Node, src []byte) []symbols.RawSymbol {
	qc := sitter.NewQueryCursor()
	defer qc.Close()
	qc.Exec(q, root)

	var result []symbols.RawSymbol
	for {
		match, ok := qc.NextMatch()
		if !ok {
			break
		}
		if sym := matchToSymbol(match, q, src); sym != nil {
			result = append(result, *sym)
		}
	}
	return result
}

func matchToSymbol(m *sitter.QueryMatch, q *sitter.Query, src []byte) *symbols.RawSymbol {
	var name string
	var defNode *sitter.Node
	var kind symbols.Kind

	for _, cap := range m.Captures {
		cn := q.CaptureNameForId(cap.Index)
		if cn == captureName {
			name = cap.Node.Content(src)
			continue
		}
		if strings.HasPrefix(cn, capturePrefix) {
			defNode = cap.Node
			kind = captureNameToKind(strings.TrimPrefix(cn, capturePrefix))
		}
	}

	if name == "" || defNode == nil {
		return nil
	}
	start, end := nodeLines(defNode)
	return &symbols.RawSymbol{Name: name, Kind: kind, StartLine: start, EndLine: end}
}

func nodeLines(n *sitter.Node) (start, end int) {
	// tree-sitter rows are 0-indexed; convert to 1-indexed line numbers.
	return int(n.StartPoint().Row) + 1, int(n.EndPoint().Row) + 1
}

func collectComments(q *sitter.Query, root *sitter.Node, src []byte) []symbols.RawComment {
	qc := sitter.NewQueryCursor()
	defer qc.Close()
	qc.Exec(q, root)

	var result []symbols.RawComment
	for {
		match, ok := qc.NextMatch()
		if !ok {
			break
		}
		for _, cap := range match.Captures {
			if q.CaptureNameForId(cap.Index) == captureComment {
				start, end := nodeLines(cap.Node)
				result = append(result, symbols.RawComment{
					Text:      cap.Node.Content(src),
					StartLine: start,
					EndLine:   end,
				})
			}
		}
	}
	return result
}

func captureNameToKind(suffix string) symbols.Kind {
	switch suffix {
	case "function":
		return symbols.KindFunction
	case "method":
		return symbols.KindMethod
	case "class":
		return symbols.KindClass
	case "struct":
		return symbols.KindStruct
	case "interface":
		return symbols.KindInterface
	case "enum":
		return symbols.KindEnum
	case "module":
		return symbols.KindModule
	default:
		return symbols.KindFunction
	}
}
