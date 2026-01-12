______________________________________________________________________

## icon: material/heart-multiple-outline

# Contributing

## Contributions are welcome

Improvement suggestion PRs to this repo are very much welcome, and I encourage
you to begin by reading the below paragraph on the adapter design and engage in
the [discussions](https://github.com/fredrikaverpil/neotest-golang/discussions)
in case the change is not trivial.

You can run tests, formatting and linting locally with `task all` (requires
[Taskfile](https://taskfile.dev/)). Install dependencies with `task install`.
Have a look at the `Taskfile.yml` for more details. You can also use the
neotest-plenary and neotest-golang adapters to run the tests of this repo within
Neovim. Please refer to the [Test setup](test.md) for detail on how to run
tests.

## AST and tree-sitter

To figure out new tree-sitter queries (for detecting tests), the following
commands are available in Neovim to aid you:

- `:Inspect` to show the highlight groups under the cursor.
- `:InspectTree` to show the parsed syntax tree (formerly known as
  "TSPlayground").
- `:EditQuery` to open the Live Query Editor (Nvim 0.10+).

For example, open up a Go test file and then execute `:InspectTree`. A new
window will appear which shows what the tree-sitter query syntax representation
looks like for the Go test file.

Again, from the Go test file, execute `:EditQuery` to open up the query editor
in a separate window. In the editor, you can now start creating your syntax
query and play around. You can paste in queries from
[`query.lua`](https://github.com/fredrikaverpil/neotest-golang/blob/main/lua/neotest-golang/query.lua)
in the editor, to see how the query behaves and highlights parts of your Go test
file.

### Required query captures

Neotest expects specific capture names in tree-sitter queries to build test
positions. The core library (`neotest/lua/neotest/lib/treesitter/init.lua`)
looks for these captures:

**For tests:**

- `@test.name` - The name/identifier of the test (required)
- `@test.definition` - The AST node representing the entire test definition
  (required)

**For testify suites:**

Testify suites use a flat structure. Receiver methods are identified via
`@namespace.name` and `@namespace.definition` captures for lookup purposes, but
these are not converted into namespace position nodes. Instead, test IDs are
prefixed with suite names (e.g., `::SuiteName/MethodName`).

The `build_position` function in Neotest's treesitter library extracts text from
the `.name` capture and uses the `.definition` capture's range to determine the
position. These captures are then converted into `neotest.Position` objects with
these fields:

- `type` - Position type: `"test"` or `"namespace"` (or `"file"` / `"dir"`)
- `path` - Absolute file path
- `name` - Test or namespace name (extracted from `.name` capture)
- `range` - Array of line/column positions from `.definition` capture's range

Additional captures like `@test.method`, `@test.operand`, etc., can be used
within queries for predicates and logic but are not directly consumed by
Neotest's position builder.

## Previewing the documentation

Install [uv](https://docs.astral.sh/uv/) with e.g. `brew install uv` or
`pip install uv`. Then:

- Run `uv venv` to create a `.venv` folder
- Activate the virtual environment with `source .venv/bin/activate`
- Run `uv sync` to install dependencies

Finally, run `uv run zensical serve` to serve the documentation and preview it on
`http://localhost:8000`.

## General design of the adapter

### Treesitter queries detect tests

Neotest leverages treesitter AST-parsing of source code to detect tests. This
adapter supplies queries so to figure out what is considered a test.

From the result of these queries, a Neotest "position" tree is built (can be
visualized through the "Neotest summary"). Each position in the tree represents
either a `dir`, `file` or `test` type. Neotest also has a notion of a
`namespace` position type, but this adapter does not use it (testify support
uses a flat structure).

### Generating valid `go test` commands

The `dir`, `file` and `test` tree position types cannot be directly translated
over to Go so to produce a valid `go test` command. Go primarily cares about a
Go package's import path, test name regexp filters and the current working
directory.

For example, these are all valid `go test` command:

```bash
# run all tests, recursing sub-packages, in the current working directory.
go test ./...

# run all tests in a given package 'x', by specifying the full import path
go test github.com/fredrikaverpil/neotest-golang/x

# run all tests in a given package 'x', recursing sub-packages
go test github.com/fredrikaverpil/neotest-golang/x/...

# run _some_ tests in a given package, based on a regexp filter
go test github.com/fredrikaverpil/neotest-golang -run "^(^TestFoo$|^TestBar$)$"
```

!!! note "Note on `go.mod`"
    All the above commands must be run somewhere beneath the location of the
    `go.mod` file specifying the _module_ name, which in this example is
    `github.com/fredrikaverpil/neotest-golang`.

I figured out that by executing `go list -json ./...` in the `go.mod` root
location, the output provides valuable information about test files/folders and
their corresponding Go package's import path. This data is key to being able to
take the Neotest/treesitter position type and generate a valid `go test` command
for it. In essence, this approach is what makes neotest-golang so robust.

### Output processing

Neotest captures the stdout from the test execution command and writes it to
disk as a temporary file. The adapter is responsible for reading the file(s) and
reporting back status and output to the Neotest tree (and specifically the
position in the tree which was executed). It is therefore crucial for outputting
structured data, which in this case is done with `go test -json`.

One challenge here is that Go build errors are not always part of the structured
JSON output (although captured in the stdout) and needs to be looked for in
other ways.

Another challenge is to properly populate statuses and errors into the
corresponding Neotest tree position. This becomes increasingly difficult when
you consider running tests in a recursive manner (e.g. `go test -json ./...`).

Errors are recorded and populated, per position type, along with its
corresponding buffer's line number. Neotest can then show the errors inline as
diagnostics.

I've taken an approach with this adapter where I record test outcome for each
Neotest position type and populate it onto each of them, when applicable.

On some systems and terminals, there are great issues with the `go test` output.
I've therefore made it possible to make the adapter rely on output saved
directly to disk without going through stdout, by leveraging `gotestsum`.

With neotest-golang v2.0, streaming support was added and required a total
rewrite of the output processing. This made the adapter logic easier to follow
and formally defined the processing steps more clearly.

When you run tests via neotest-golang, the following happens:

- **Runspec preparation**: `go list -json` gathers package data and creates a
  lookup (`mapping.lua`) mapping Neotest positions to Go tests.
- **Streaming execution** (`results_stream.lua`):
  - Go test JSON events are processed in real-time as they arrive.
  - Results are cached directly for immediate feedback.
  - Test output files are written synchronously when tests complete.
- **Finalization** (`results_finalize.lua`):
  - Stops streaming and transfers cached results atomically.
  - Performs aggregation for file/directory nodes in the Neotest tree.
  - All test output is already available from the streaming phase.
