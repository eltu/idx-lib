package treesitter

import (
	"embed"
	"fmt"

	sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_go "github.com/tree-sitter/tree-sitter-go/bindings/go"
	tree_sitter_java "github.com/tree-sitter/tree-sitter-java/bindings/go"
	tree_sitter_javascript "github.com/tree-sitter/tree-sitter-javascript/bindings/go"
	tree_sitter_python "github.com/tree-sitter/tree-sitter-python/bindings/go"
	tree_sitter_ruby "github.com/tree-sitter/tree-sitter-ruby/bindings/go"
	tree_sitter_rust "github.com/tree-sitter/tree-sitter-rust/bindings/go"
	tree_sitter_typescript "github.com/tree-sitter/tree-sitter-typescript/bindings/go"

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
	r.mustRegister(lang.Go, sitter.NewLanguage(tree_sitter_go.Language()), "go.scm", "go_comments.scm")
	r.mustRegister(lang.Python, sitter.NewLanguage(tree_sitter_python.Language()), "python.scm", "python_comments.scm")
	r.mustRegister(lang.JavaScript, sitter.NewLanguage(tree_sitter_javascript.Language()), "javascript.scm", "javascript_comments.scm")
	r.mustRegister(lang.TypeScript, sitter.NewLanguage(tree_sitter_typescript.LanguageTypescript()), "typescript.scm", "typescript_comments.scm")
	r.mustRegister(lang.Java, sitter.NewLanguage(tree_sitter_java.Language()), "java.scm", "java_comments.scm")
	r.mustRegister(lang.Ruby, sitter.NewLanguage(tree_sitter_ruby.Language()), "ruby.scm", "ruby_comments.scm")
	r.mustRegister(lang.Rust, sitter.NewLanguage(tree_sitter_rust.Language()), "rust.scm", "rust_comments.scm")
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
	q, qErr := sitter.NewQuery(grammar, string(raw))
	if qErr != nil {
		panic(fmt.Sprintf("treesitter: invalid query in %q: %v", filename, qErr))
	}
	return q
}
