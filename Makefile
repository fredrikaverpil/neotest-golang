TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

# --- Default targets ---

.PHONY: install
install: install-go-tooling
.PHONY: install-go-tooling
install-go-tooling: install-format-go install-lint-go install-vuln-go
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


# --- Targets ---

# https://lazy.folke.io/developers#minit-minimal-init
# https://www.reddit.com/r/neovim/comments/1dr5152/testing_your_neovim_plugins_with_busted_and/

.PHONY: lazy
lazy:
	mkdir -p .tests
	git clone --depth 1 https://github.com/folke/lazy.nvim.git .tests/lazy.nvim

.PHONY: test-lua
test-lua: lazy
	./scripts/test

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
		gci write --skip-generated --skip-vendor -s standard -s default . && \
		golines --base-formatter=gofumpt --ignore-generated --tab-len=1 --max-len=120 --write-output .

.PHONY: lint-go
lint-go:
	cd tests/go && \
		golangci-lint run --verbose ./... && \
		go vet ./...

.PHONY: vuln-go
vuln-go:
	cd tests/go && \
		govulncheck ./... && \
		gosec ./...

.PHONY: git-diff
git-diff:
	git diff --exit-code

# --- Installation of tooling ---

.PHONY: install-format-go
install-format-go:
	go install github.com/daixiang0/gci@latest && \
		go install github.com/segmentio/golines@latest && \
		go install mvdan.cc/gofumpt@latest	# NOTE: golines uses gofumpt

.PHONY: install-lint-go
install-lint-go:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

.PHONY: install-vuln-go
install-vuln-go:
	go install golang.org/x/vuln/cmd/govulncheck@latest
	go install github.com/securego/gosec/v2/cmd/gosec@latest

