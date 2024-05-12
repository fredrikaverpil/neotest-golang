#!/bin/bash
set -e

# This script is executed by tests/minimal_init.lua
REPOS=(
	"https://github.com/nvim-lua/plenary.nvim"
	"https://github.com/nvim-telescope/telescope.nvim"
	"https://github.com/neovim/nvim-lspconfig"
	"https://github.com/nvim-neotest/nvim-nio"
	"https://github.com/nvim-neotest/neotest"
	"https://github.com/nvim-treesitter/nvim-treesitter"
)
THIS_SCRIPT_FILE=$(readlink -f "${BASH_SOURCE[0]}")
REPO_DIR=$(dirname "$(dirname "$THIS_SCRIPT_FILE")")
TEST_ALL_DIR="$REPO_DIR/.tests/all/site/pack/deps/start"

clone() {
	repo=$1
	dest=$2
	if [ ! -d "$dest" ]; then
		git clone --depth 1 "$repo" "$dest"
	fi
}

# Just for the main minimal_init.lua for neotest
mkdir -p $TEST_ALL_DIR
for repo in "${REPOS[@]}"; do
	clone "$repo" "$TEST_ALL_DIR/$(basename $repo)"
done
