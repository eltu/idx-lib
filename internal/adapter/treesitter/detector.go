package treesitter

import (
	"strings"

	"github.com/eltu/idx-lib/internal/features/lang"
)

// ExtensionDetector maps file extensions to language IDs.
type ExtensionDetector struct{}

// NewExtensionDetector creates an ExtensionDetector.
// Example:
//
//	d := treesitter.NewExtensionDetector()
//	id := d.Detect(lang.SourceFile{Extension: ".go"})
func NewExtensionDetector() *ExtensionDetector { return &ExtensionDetector{} }

// Detect returns the language ID for the given source file based on its extension.
// Recognizes both dot-prefixed and plain extensions (e.g. ".go" and "go").
// Returns lang.Unknown for unrecognized extensions.
// Example:
//
//	id := d.Detect(lang.SourceFile{Extension: ".py"}) // → lang.Python
func (d *ExtensionDetector) Detect(file lang.SourceFile) lang.ID {
	ext := strings.ToLower(strings.TrimPrefix(file.Extension, "."))
	switch ext {
	case "go":
		return lang.Go
	case "py":
		return lang.Python
	case "js":
		return lang.JavaScript
	case "ts":
		return lang.TypeScript
	case "java":
		return lang.Java
	case "rb":
		return lang.Ruby
	case "rs":
		return lang.Rust
	default:
		return lang.Unknown
	}
}
