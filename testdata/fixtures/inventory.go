// Package fixtures exposes the list of language fixture files for use in tests.
package fixtures

import (
	"os"
	"path/filepath"
	"runtime"
)

// Language describes a fixture file and the programming language it represents.
type Language struct {
	// Name is the display name of the language.
	Name string
	// Extension is the canonical file extension (without leading dot).
	Extension string
	// FilePath is the absolute path to the sample file.
	FilePath string
}

var (
	_, callerFile, _, _ = runtime.Caller(0)
	// srcDir points to testdata/fixtures/src/ where the language sample files live.
	srcDir = filepath.Join(filepath.Dir(callerFile), "src")
)

// All returns every Language fixture available under testdata/fixtures/.
// Each entry is guaranteed to exist on disk at the time the slice is built.
func All() []Language {
	langs := []Language{
		{Name: "Go", Extension: "go"},
		{Name: "Java", Extension: "java"},
		{Name: "JavaScript", Extension: "js"},
		{Name: "Python", Extension: "py"},
		{Name: "Ruby", Extension: "rb"},
		{Name: "Rust", Extension: "rs"},
		{Name: "TypeScript", Extension: "ts"},
	}
	for i, l := range langs {
		langs[i].FilePath = filepath.Join(srcDir, "sample."+l.Extension)
	}
	return langs
}

// MustReadFile reads the fixture file for the given extension and panics if it
// cannot be opened. Intended for use in tests via testdata helpers.
func MustReadFile(extension string) []byte {
	path := filepath.Join(srcDir, "sample."+extension)
	data, err := os.ReadFile(path)
	if err != nil {
		panic("fixture not found: " + path)
	}
	return data
}
