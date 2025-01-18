---
icon: material/information
---

--8<-- "README.md"

---

??? question "Why a second Neotest adapter for Go? 🤔"

    While using [neotest-go](https://github.com/nvim-neotest/neotest-go) I stumbled
    upon many problems which seemed difficult to solve in that codebase.

    I have full respect for the time and efforts put in by the developer(s) of
    neotest-go. I do not aim in any way to diminish their needs or efforts. However,
    I wanted to see if I could fix these issues by diving into the 🕳️🐇 of Neotest
    and building my own adapter. Below is a list of neotest-go issues which are not
    present in neotest-golang (this project):

    | Neotest-go issue                                        | URL                                                                   |
    | ------------------------------------------------------- | --------------------------------------------------------------------- |
    | Support for Testify framework                           | [neotest-go#6](https://github.com/nvim-neotest/neotest-go/issues/6)   |
    | DAP support                                             | [neotest-go#12](https://github.com/nvim-neotest/neotest-go/issues/12) |
    | Test Output in JSON, making it difficult to read        | [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52) |
    | Support for Nested Subtests                             | [neotest-go#74](https://github.com/nvim-neotest/neotest-go/issues/74) |
    | Diagnostics for table tests on the line of failure      | [neotest-go#75](https://github.com/nvim-neotest/neotest-go/issues/75) |
    | "Run nearest" runs all tests                            | [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83) |
    | Table tests not recognized when defined inside for-loop | [neotest-go#86](https://github.com/nvim-neotest/neotest-go/issues/86) |
    | Running test suite doesn't work                         | [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89) |

    A comparison in number of GitHub stars between the projects:

    [![Star History Chart](https://api.star-history.com/svg?repos=fredrikaverpil/neotest-golang,nvim-neotest/neotest-go&type=Date)](https://star-history.com/#fredrikaverpil/neotest-golang&nvim-neotest/neotest-go&Date)
