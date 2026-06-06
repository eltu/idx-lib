package treesitter

import (
	"embed"
	"fmt"

	sitter "github.com/smacker/go-tree-sitter"
	"github.com/smacker/go-tree-sitter/golang"
	"github.com/smacker/go-tree-sitter/java"
	"github.com/smacker/go-tree-sitter/javascript"
	"github.com/smacker/go-tree-sitter/python"
	"github.com/smacker/go-tree-sitter/ruby"
	"github.com/smacker/go-tree-sitter/rust"
	"github.com/smacker/go-tree-sitter/typescript/typescript"

	"github.com/eltu/idx-lib/internal/features/lang"
)

//go:embed queries
var queryFiles embed.FS

const queryDir = "queries/"

// langConfig holds the compiled grammar and queries for a single language.
type langConfig struct {
	grammar      *sitter.Language
	query        *sitter.Query
	commentQuery *sitter.Query
}

// Registry maps language IDs to their tree-sitter grammar and compiled query.
type Registry struct {
	configs map[lang.ID]langConfig
}

// NewRegistry creates a Registry with all supported languages pre-configured.
// Panics if any bundled query is syntactically invalid — this indicates a
// programming error in the embedded .scm files.
// Example:
//
//	reg := treesitter.NewRegistry()
func NewRegistry() *Registry {
	r := &Registry{configs: make(map[lang.ID]langConfig)}
	r.mustRegister(lang.Go, golang.GetLanguage(), "go.scm", "go_comments.scm")
	r.mustRegister(lang.Python, python.GetLanguage(), "python.scm", "python_comments.scm")
	r.mustRegister(lang.JavaScript, javascript.GetLanguage(), "javascript.scm", "javascript_comments.scm")
	r.mustRegister(lang.TypeScript, typescript.GetLanguage(), "typescript.scm", "typescript_comments.scm")
	r.mustRegister(lang.Java, java.GetLanguage(), "java.scm", "java_comments.scm")
	r.mustRegister(lang.Ruby, ruby.GetLanguage(), "ruby.scm", "ruby_comments.scm")
	r.mustRegister(lang.Rust, rust.GetLanguage(), "rust.scm", "rust_comments.scm")
	return r
}

// Config returns the langConfig for id, and false if the language is not registered.
func (r *Registry) Config(id lang.ID) (langConfig, bool) {
	c, ok := r.configs[id]
	return c, ok
}

func (r *Registry) mustRegister(id lang.ID, grammar *sitter.Language, symbolFile, commentFile string) {
	q := r.mustCompileQuery(grammar, symbolFile)
	cq := r.mustCompileQuery(grammar, commentFile)
	r.configs[id] = langConfig{grammar: grammar, query: q, commentQuery: cq}
}

func (r *Registry) mustCompileQuery(grammar *sitter.Language, filename string) *sitter.Query {
	raw, err := queryFiles.ReadFile(queryDir + filename)
	if err != nil {
		panic(fmt.Sprintf("treesitter: missing query file %q: %v", filename, err))
	}
	q, err := sitter.NewQuery(raw, grammar)
	if err != nil {
		panic(fmt.Sprintf("treesitter: invalid query in %q: %v", filename, err))
	}
	return q
}
