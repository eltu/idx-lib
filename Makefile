ALL_PKGS    := ./...
CYCLO_LIMIT := 15

.PHONY: fmt lint test coverage complexity check pre-push hooks clean

GOLANGCI := $(shell go env GOPATH)/bin/golangci-lint

## Apply gofmt to all Go source files
fmt:
	gofmt -w $$(find . -name '*.go' -not -path './.git/*')

## Run golangci-lint (configured via .golangci.yml)
lint:
	$(GOLANGCI) run $(ALL_PKGS)

## Run unit tests
test:
	go test $(ALL_PKGS)

## Run unit tests with coverage report (used by SonarCloud)
coverage:
	go test $(ALL_PKGS) -coverprofile=coverage.out -covermode=atomic

## Fail when any function exceeds cyclomatic complexity threshold
complexity:
	@go run github.com/fzipp/gocyclo/cmd/gocyclo@latest . | sort -rn | awk -v limit=$(CYCLO_LIMIT) '$$0 !~ /_test\.go:/ && $$1 > limit {print; found=1} END {if (found) exit 1}'

## fmt + lint + test — also used as the pre-push gate
check: fmt lint test

## Git pre-push hook entry point — delegates to check
pre-push: check

## Bootstrap dev environment: installs golangci-lint + git hooks (run once after cloning)
hooks:
	@sh scripts/setup

## Remove build artifacts
clean:
	rm -f coverage.out
