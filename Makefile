.PHONY: check unit-test e2e-test clean

check: unit-test e2e-test

unit-test:
	@./test/busted --run unit

# e2e-test:
# 	@./test/busted --run e2e

clean:
	@rm -rf test/xdg/local/state/nvim/*
	@rm -rf test/xdg/local/share/nvim/site/pack/testing/start/nvim-treesitter/parser/*
	@# The symlink might have been left over from a failed test run
	@rm -rf test/xdg/local/share/nvim/site/pack/self-*
