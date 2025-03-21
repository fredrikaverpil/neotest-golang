# --- Default targets ---

.PHONY: all
all: test format lint vuln git-diff

.PHONY: test
test: test-lua test-go

.PHONY: format
format: format-go

.PHONY: lint
lint: lint-go

.PHONY: vuln
vuln: vuln-go

# --- Tool definitions ---

TOOLS_MODFILE := $(CURDIR)/tools/go.mod
GCI := go tool -modfile=$(TOOLS_MODFILE) github.com/daixiang0/gci
GOLINES := go tool -modfile=$(TOOLS_MODFILE) github.com/segmentio/golines
GOFUMPT := go tool -modfile=$(TOOLS_MODFILE) mvdan.cc/gofumpt
GOLANGCI_LINT := go tool -modfile=$(TOOLS_MODFILE) github.com/golangci/golangci-lint/cmd/golangci-lint
GOVULNCHECK := go tool -modfile=$(TOOLS_MODFILE) golang.org/x/vuln/cmd/govulncheck
GOSEC := go tool -modfile=$(TOOLS_MODFILE) github.com/securego/gosec/v2/cmd/gosec
GOIMPORTS := go tool -modfile=$(TOOLS_MODFILE) golang.org/x/tools/cmd/goimports

# --- Targets ---

.PHONY: clean
clean:
	rm -rf .tests

.PHONY: test-lua
test-lua:
	nvim \
		--headless \
		--noplugin \
		-i NONE \
		-u tests/bootstrap.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', timeout = 50000 }"

.PHONY: test-go
test-go:
	# Do not allow tests to be skipped
	@cd tests/go && output=$$(go test -v -count=1 ./...); \
	echo "$$output"; \
	if echo "$$output" | grep -q "SKIP"; then \
		echo "Error: Skipped tests detected"; \
		exit 1; \
	fi

.PHONY: format-go
format-go:
	cd tests/go && \
		$(GCI) write --skip-generated --skip-vendor -s standard -s default . && \
		$(GOLINES) --base-formatter=gofumpt --ignore-generated --tab-len=1 --max-len=120 --write-output .

.PHONY: lint-go
lint-go:
	cd tests/go && \
		$(GOLANGCI_LINT) run --verbose ./... && \
		go vet ./...

.PHONY: vuln-go
vuln-go:
	cd tests/go && \
		$(GOVULNCHECK) ./... && \
		$(GOSEC) ./...

.PHONY: git-diff
git-diff:
	git diff --exit-code
