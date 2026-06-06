package parser

import "strings"

// decorativeChars are the only characters that appear in separator-style comments.
// A line consisting solely of these characters carries no semantic content.
const decorativeChars = "-=*+|/# "

// cleanCommentBody strips syntactic comment markers from text and returns the
// semantic content. Returns "" for comments that contain only decorative separators.
// Example:
//
//	cleanCommentBody("// Constants & iota") // => "Constants & iota"
//	cleanCommentBody("// --------- //")     // => ""
func cleanCommentBody(text string) string {
	if strings.HasPrefix(text, "/*") {
		return stripBlockComment(text)
	}
	return stripLineComment(text)
}

func stripLineComment(text string) string {
	stripped := strings.TrimSpace(removeLineMarker(text))
	if isDecorativeLine(stripped) {
		return ""
	}
	return stripped
}

func removeLineMarker(line string) string {
	switch {
	case strings.HasPrefix(line, "//!"):
		return strings.TrimPrefix(line, "//!")
	case strings.HasPrefix(line, "///"):
		return strings.TrimPrefix(line, "///")
	case strings.HasPrefix(line, "//"):
		return strings.TrimPrefix(line, "//")
	case strings.HasPrefix(line, "#"):
		return strings.TrimPrefix(line, "#")
	default:
		return line
	}
}

func stripBlockComment(text string) string {
	s := strings.TrimSpace(text)
	s = strings.TrimPrefix(s, "/**")
	s = strings.TrimPrefix(s, "/*")
	s = strings.TrimSuffix(s, "*/")

	var body []string
	for _, line := range strings.Split(s, "\n") {
		content := stripBlockInteriorLine(line)
		if content != "" && !isDecorativeLine(content) {
			body = append(body, content)
		}
	}
	return strings.Join(body, "\n")
}

func stripBlockInteriorLine(line string) string {
	s := strings.TrimSpace(line)
	if strings.HasPrefix(s, "* ") {
		return strings.TrimPrefix(s, "* ")
	}
	if s == "*" || s == "**" {
		return ""
	}
	return s
}

// groupConsecutiveComments merges comment entries whose lines are immediately
// adjacent (endLine + 1 == nextStartLine) into a single entry with context
// lines joined by newlines.
func groupConsecutiveComments(comments []Comment) []Comment {
	if len(comments) == 0 {
		return comments
	}
	grouped := []Comment{comments[0]}
	for _, c := range comments[1:] {
		last := &grouped[len(grouped)-1]
		if c.StartLine == last.EndLine+1 {
			last.Context += "\n" + c.Context
			last.EndLine = c.EndLine
		} else {
			grouped = append(grouped, c)
		}
	}
	return grouped
}

func isDecorativeLine(line string) bool {
	for _, r := range line {
		if !strings.ContainsRune(decorativeChars, r) {
			return false
		}
	}
	return true
}
