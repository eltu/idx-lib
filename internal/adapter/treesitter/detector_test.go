package treesitter_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/eltu/idx-lib/internal/adapter/treesitter"
	"github.com/eltu/idx-lib/internal/features/lang"
)

func TestExtensionDetector_Detect_ReturnsCorrectIDForKnownExtensions(t *testing.T) {
	t.Parallel()

	tests := []struct {
		ext      string
		expected lang.ID
	}{
		{".go", lang.Go},
		{"go", lang.Go},
		{".py", lang.Python},
		{"py", lang.Python},
		{".js", lang.JavaScript},
		{"js", lang.JavaScript},
		{".ts", lang.TypeScript},
		{"ts", lang.TypeScript},
		{".java", lang.Java},
		{"java", lang.Java},
		{".rb", lang.Ruby},
		{"rb", lang.Ruby},
		{".rs", lang.Rust},
		{"rs", lang.Rust},
	}

	d := treesitter.NewExtensionDetector()

	for _, tc := range tests {
		tc := tc
		t.Run(tc.ext, func(t *testing.T) {
			t.Parallel()

			// Arrange
			file := lang.SourceFile{Extension: tc.ext}

			// Act
			got := d.Detect(file)

			// Assert
			assert.Equal(t, tc.expected, got)
		})
	}
}

func TestExtensionDetector_Detect_ReturnsUnknownForUnrecognizedExtension(t *testing.T) {
	t.Parallel()

	tests := []struct{ ext string }{
		{".xyz"},
		{"html"},
		{""},
		{".dart"},
	}

	d := treesitter.NewExtensionDetector()

	for _, tc := range tests {
		tc := tc
		t.Run(tc.ext, func(t *testing.T) {
			t.Parallel()

			// Act
			got := d.Detect(lang.SourceFile{Extension: tc.ext})

			// Assert
			assert.Equal(t, lang.Unknown, got)
		})
	}
}
