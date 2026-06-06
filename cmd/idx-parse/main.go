// idx-parse reads a source file and prints its extracted symbols as JSON.
//
// Usage:
//
//	idx-parse <file>
//	idx-parse <file> --kind function
//	idx-parse <file> --name get
//
// The language is detected automatically from the file extension.
// Supported extensions: .go .py .js .ts .java .rb .rs
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/eltu/idx-lib/parser"
)

const usage = `Usage: idx-parse <file> [--kind <kind>] [--name <substring>]

Supported kinds: function, method, class, struct, interface, enum, module
Supported extensions: .go .py .js .ts .java .rb .rs

Examples:
  idx-parse testdata/fixtures/src/sample.go
  idx-parse testdata/fixtures/src/sample.py --kind class
  idx-parse testdata/fixtures/src/sample.rs --kind function --name fibonacci`

func main() {
	args, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		fmt.Fprintln(os.Stderr, usage)
		os.Exit(1)
	}

	src, err := os.ReadFile(args.file)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error reading file:", err)
		os.Exit(1)
	}

	ext := filepath.Ext(args.file)
	e := parser.NewSymbolExtractor()
	result, err := e.Extract(src, ext)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error parsing:", err)
		os.Exit(1)
	}

	filtered := parser.Filter{
		Kinds:        args.kinds,
		NameContains: args.name,
	}.Apply(result)

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(filtered); err != nil {
		fmt.Fprintln(os.Stderr, "error encoding JSON:", err)
		os.Exit(1)
	}
}

type cliArgs struct {
	file  string
	kinds []parser.SymbolKind
	name  string
}

func parseArgs(args []string) (cliArgs, error) {
	if len(args) == 0 {
		return cliArgs{}, fmt.Errorf("no file specified")
	}

	result := cliArgs{file: args[0]}
	rest := args[1:]

	for i := 0; i < len(rest); i++ {
		switch rest[i] {
		case "--kind":
			if i+1 >= len(rest) {
				return cliArgs{}, fmt.Errorf("--kind requires a value")
			}
			i++
			k, err := parseKind(rest[i])
			if err != nil {
				return cliArgs{}, err
			}
			result.kinds = append(result.kinds, k)
		case "--name":
			if i+1 >= len(rest) {
				return cliArgs{}, fmt.Errorf("--name requires a value")
			}
			i++
			result.name = rest[i]
		default:
			return cliArgs{}, fmt.Errorf("unknown flag: %s", rest[i])
		}
	}
	return result, nil
}

func parseKind(s string) (parser.SymbolKind, error) {
	valid := []parser.SymbolKind{
		parser.SymbolFunction, parser.SymbolMethod, parser.SymbolClass,
		parser.SymbolStruct, parser.SymbolInterface, parser.SymbolEnum, parser.SymbolModule,
	}
	for _, k := range valid {
		if strings.EqualFold(string(k), s) {
			return k, nil
		}
	}
	return "", fmt.Errorf("unknown kind %q — valid: function, method, class, struct, interface, enum, module", s)
}
