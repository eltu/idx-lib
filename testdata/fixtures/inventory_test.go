package fixtures_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	fixtures "github.com/eltu/idx-lib/testdata/fixtures"
)

func TestAll_ReturnsAllLanguages(t *testing.T) {
	t.Parallel()

	// Arrange
	langs := fixtures.All()

	// Assert
	assert.Len(t, langs, 25, "expected 25 language fixtures")
}

func TestAll_FilesExistOnDisk(t *testing.T) {
	t.Parallel()

	for _, lang := range fixtures.All() {
		lang := lang
		t.Run(lang.Name, func(t *testing.T) {
			t.Parallel()

			// Arrange & Act
			_, err := os.Stat(lang.FilePath)

			// Assert
			require.NoError(t, err, "fixture file must exist for %s", lang.Name)
		})
	}
}

func TestMustReadFile_ReturnsContent(t *testing.T) {
	t.Parallel()

	// Act
	data := fixtures.MustReadFile("go")

	// Assert
	assert.NotEmpty(t, data, "go fixture must not be empty")
}

func TestMustReadFile_PanicsForMissingExtension(t *testing.T) {
	t.Parallel()

	// Assert
	assert.Panics(t, func() {
		fixtures.MustReadFile("nonexistent")
	})
}
