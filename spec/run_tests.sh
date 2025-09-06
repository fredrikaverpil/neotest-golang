#!/bin/bash

# Test runner script for CI, based on neotest-busted pattern
# This runs PlenaryBusted within Neovim context to access vim APIs and plugins

tempfile=".test_output.tmp"

if [[ -n $1 ]]; then
	# Run specific file
	nvim --headless --noplugin -u spec/busted_bootstrap.lua -c "PlenaryBustedFile $1" | tee "${tempfile}"
else
	# Run all tests in spec/ directory
	nvim --headless --noplugin -u spec/busted_bootstrap.lua -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/busted_bootstrap.lua'}" | tee "${tempfile}"
fi

# Plenary doesn't emit exit code 1 when tests have errors during setup
errors=$(sed 's/\x1b\[[0-9;]*m//g' "${tempfile}" | awk '/(Errors|Failed) :/ {print $3}' | grep -v '0')

rm "${tempfile}"

if [[ -n $errors ]]; then
	echo "Tests failed"
	exit 1
fi

exit 0
