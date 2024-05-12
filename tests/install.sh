#!/bin/bash
set -e

# This script is executed via tests/minimal_init.lua

GITHUB="https://github.com"
GITHUB_PLENARY="$GITHUB/nvim-lua/plenary.nvim"
GITHUB_TELESCOPE="$GITHUB/nvim-telescope/telescope.nvim"
GITHUB_LSPCONFIG="$GITHUB/neovim/nvim-lspconfig"
GITHUB_NIO="$GITHUB/nvim-neotest/nvim-nio"
GITHUB_NEOTEST="$GITHUB/nvim-neotest/neotest"
GITHUB_TREESITTER="$GITHUB/nvim-treesitter/nvim-treesitter"

SCRIPT_FILE=$(readlink -f "${BASH_SOURCE[0]}")
REPO_DIR=$(dirname "$(dirname "$SCRIPT_FILE")")

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
clone $GITHUB_PLENARY "$TEST_ALL_DIR/plenary.nvim"
clone $GITHUB_LSPCONFIG "$TEST_ALL_DIR/lspconfig.nvim"
clone $GITHUB_TELESCOPE "$TEST_ALL_DIR/telescope.nvim"
clone $GITHUB_NIO "$TEST_ALL_DIR/nvim-nio"
clone $GITHUB_NEOTEST "$TEST_ALL_DIR/neotest"
clone $GITHUB_TREESITTER "$TEST_ALL_DIR/nvim-treesitter"
