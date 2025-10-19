# Task to do

## Overview

Implement more robust [testify](https://github.com/stretchr/testify) support to
this Neotest adapter for running Go tests.

## Background

- We today support testify suites via enabling the optional `testify_enabled`
  config flag.
- Neotest supports test, file, dir and namespace positions to place in its tree.
- We today represent a testify suite using the namespace position, and we place
  the tests inside the suite as children of the namespace.
- Unfortunately, Neotest's "run nearest test" feature works very poorly today.
  We have attempted to fix this using two primary approaches in the past:
  - Gap (HISTORY/GAP.md): branch `fix/testify-nearest`
  - Method ownership (HISTORY/METHOD_OWNERSHIP.md): branch
    `fix/testify-nearest-v2`
- We have realized we also have a different problem at hour hands in regards to
  testify suites: https://github.com/fredrikaverpil/neotest-golang/issues/482
  which we might keep in mind when implementing the new support for testify.

You can find details on how the "run nearest test" feature works in
HISTORY/NEAREST.md.

## New idea

Today, we create a Neotest tree by first detecting testify suites and test
methods using Neotest's built-in AST parsing via queries. Then we build a lookup
which contains the test methods and which suite they belong to. Finally we
modify the Neotest tree, so that we end up with a suite namespace which holds
the testify tests:

```
neotest-golang  112  0  0  0  0
╰╮  tests
 ├╮  features
 │╰╮  internal
 │ ├─  outputsanitization
 │ ╰╮  testifysuites
 │  ├─  diagnostics_test.go
 │  ├╮  othersuite_test.go
 │  │╰╮  TestOtherTestSuite
 │  │ ╰─  TestOther
 │  ├╮  positions_test.go         <-- more complex testify examples
 │  │├╮  TestExampleTestSuite
 │  ││├─  TestExample
 │  ││├─  TestExample2
 │  ││├╮  TestSubTestOperand1
 │  │││╰─  "subtest"
 │  ││╰╮  TestSubTestOperand2
 │  ││ ╰─  "subtest"
 │  │├╮  TestExampleTestSuite2
 │  ││├─  TestExample
 │  ││╰─  TestExample2
 │  ││╰─  TestExample3
 │  │╰─  TestTrivial
 │  ├╮  regression_test.go   <-- simplest testify examples
 │  │╰╮  Test_MySuite        <-- testify suite
 │  │ ├─  Test_MyTest1       <-- testify test
 │  │ ╰─  Test_MyTest2       <-- testify test
 │  ╰╮  subtest_test.go
 │   ├╮  TestMixedTestSuite
 │   │├─  TestSuiteMethod1
 │   │├╮  TestSuiteMethodWithSubtests
 │   ││├─  "SuiteSubtest1"
 │   ││╰─  "SuiteSubtest2"
 │   │╰╮  TestSuiteMethodWithSubtests2
 │   │ ╰─  "SuiteSubtest3"
 │   ├╮  TestRegularWithSubtests
 │   │├─  "RegularSubtest1"
 │   │╰─  "RegularSubtest2"
 │   ╰─  TestRegularWithoutSubtests
 ╰─  go
```

But when we now have attempted to better support "run nearest test", it simply
does not work well because of how Neotest's algorithm works (I think, but I'm
not sure this is the core reason). To explain this in simple terms; if testify
tests are mixed in the file with regular tests, the order of the tests in the
file could be something this:

```go

type ExampleTestSuite2 struct {
    suite.Suite
    VariableThatShouldStartAtFive int
}

func (suite *ExampleTestSuite2) SetupTest() {
    suite.VariableThatShouldStartAtFive = 5
}

func (suite *ExampleTestSuite2) TestExample() {
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func TestTrivial(t *testing.T) {
    assert.Equal(t, 1, 1)
}

func (suite *ExampleTestSuite2) TestExample3() {
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

```

Here you see how we _would_ like to have a tree like:

```
 │  │├╮  TestExampleTestSuite2
 │  ││├─  TestExample
 │  ││╰─  TestExample2
 │  ││╰─  TestExample3
 │  │╰─  TestTrivial
```

But it does not seem like Neotest's "nearest test" algorithm will understand
this. It will see it as if the tests were in the order specified in the file.

Therefore, a new idea, for making testify support more robust, is to not inject
the namespace nodes into the tree and instead prefix all testify tests with its
suite:

```
TestExampleTestSuite2/TestExample
TestExampleTestSuite2/TestExample2
TestExampleTestSuite2/TestExample3
TestTrivial
```

Now, "nearest test" would work much better.

This means we would change the implementation of how we modify the Neotest tree:

- Stop injecting the suite as a namespace node.
- Rename the test position's ID to say
  `/path/to/file_test.go::SuiteName/TestName` for testify tests.

We still need to perform the same queries, I believe, use the same lookup but
primarily modify the tree modification. However, while we are at this, we might
want to take the bug into consideration described in issue #482.

## Important notes

- Do you see some other potential solution to this problem?
- You cannot run "nearest test" yourself in an easy manner. We should begin to
  create a way to do this. You might need to inspect the Neotest codebase to
  find out how to best do this (see the `.tests` folder in which the Neotest
  source code resides).
