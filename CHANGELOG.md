# Changelog

## [1.2.0](https://github.com/fredrikaverpil/neotest-golang/compare/v1.1.1...v1.2.0) (2024-09-18)


### Features

* add ability to pass args as function instead of table ([#188](https://github.com/fredrikaverpil/neotest-golang/issues/188)) ([c5df84c](https://github.com/fredrikaverpil/neotest-golang/commit/c5df84cddf75166cf5b81b9385c6bd2858d50aed))

## [1.1.1](https://github.com/fredrikaverpil/neotest-golang/compare/v1.1.0...v1.1.1) (2024-09-09)


### Bug Fixes

* do not detect TestMain as test function ([#183](https://github.com/fredrikaverpil/neotest-golang/issues/183)) ([b96b1cb](https://github.com/fredrikaverpil/neotest-golang/commit/b96b1cb3caf19830a56717e2f4e42359af5caaac))

## [1.1.0](https://github.com/fredrikaverpil/neotest-golang/compare/v1.0.0...v1.1.0) (2024-09-09)


### Features

* show compilation failure as test output ([#176](https://github.com/fredrikaverpil/neotest-golang/issues/176)) ([4c95fac](https://github.com/fredrikaverpil/neotest-golang/commit/4c95fac7268f365e6aa1f7e9b438b5ea161437c9))
* added go_list_args option to configuration ([#172](https://github.com/fredrikaverpil/neotest-golang/issues/172)) ([a4d9968](https://github.com/fredrikaverpil/neotest-golang/commit/a4d99687c50259c25fa0e17d268ddbe2dad88abe))

### Bug Fixes

* keep all lines until next log entry ([#179](https://github.com/fredrikaverpil/neotest-golang/issues/179)) ([8e3698a](https://github.com/fredrikaverpil/neotest-golang/commit/8e3698a7882dd9030c0033c5fe6a54df3d96ecde))
* use build flags for delve in dap-go config ([#178](https://github.com/fredrikaverpil/neotest-golang/issues/178)) ([71f7151](https://github.com/fredrikaverpil/neotest-golang/commit/71f7151dae1a557f2a1732ff93dbf39c3df123c1))

## [1.0.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.11.0...v1.0.0) (2024-08-17)


### ⚠ BREAKING CHANGES

* broken 'go list' report on some systems (requires nvim 0.10.0) ([#167](https://github.com/fredrikaverpil/neotest-golang/issues/167))

### Bug Fixes

* broken 'go list' report on some systems ([#167](https://github.com/fredrikaverpil/neotest-golang/issues/167)) ([26d937f](https://github.com/fredrikaverpil/neotest-golang/commit/26d937f53d9566a401797e3a50a946f42c4b500c))

## [0.11.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.10.0...v0.11.0) (2024-08-01)


### Features

* support luarocks/rocks.nvim ([#154](https://github.com/fredrikaverpil/neotest-golang/issues/154)) ([d040988](https://github.com/fredrikaverpil/neotest-golang/commit/d040988cceb319e93f666220c6b2c46bc4ed1f60))

## [0.10.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.9.1...v0.10.0) (2024-07-23)


### Features

* windows support ([#149](https://github.com/fredrikaverpil/neotest-golang/issues/149)) ([956ba1b](https://github.com/fredrikaverpil/neotest-golang/commit/956ba1b60a1afabf0ef9b4a096b81f6d0ba51703))

## [0.9.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.9.0...v0.9.1) (2024-07-15)


### Bug Fixes

* **dap:** show config error, remove excessive regex characters from test name ([#141](https://github.com/fredrikaverpil/neotest-golang/issues/141)) ([91dabb0](https://github.com/fredrikaverpil/neotest-golang/commit/91dabb01aef5ba3e0e7db86ff9d6dc66c58c65af))

## [0.9.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.8.1...v0.9.0) (2024-07-15)


### Features

* add logger ([#138](https://github.com/fredrikaverpil/neotest-golang/issues/138)) ([d7cf086](https://github.com/fredrikaverpil/neotest-golang/commit/d7cf0861e1b9b1c08ef8fdfa0ffbb68788294656))

## [0.8.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.8.0...v0.8.1) (2024-07-14)


### Bug Fixes

* include sub-test in test output ([#133](https://github.com/fredrikaverpil/neotest-golang/issues/133)) ([50c3d56](https://github.com/fredrikaverpil/neotest-golang/commit/50c3d569a57157e73216582a638cbb9fde023424))

## [0.8.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.7.0...v0.8.0) (2024-07-13)


### Features

* re-generate testify lookup ([#128](https://github.com/fredrikaverpil/neotest-golang/issues/128)) ([b26c220](https://github.com/fredrikaverpil/neotest-golang/commit/b26c220021f6dd42553f075f528dc0b1812522bd))


### Bug Fixes

* always recreate lookup for file ([#131](https://github.com/fredrikaverpil/neotest-golang/issues/131)) ([01792c4](https://github.com/fredrikaverpil/neotest-golang/commit/01792c4e56d17a9bfce39ac10acd4d9f242b50a1))
* find_upwards could go into infinite loop ([#129](https://github.com/fredrikaverpil/neotest-golang/issues/129)) ([b9cc68c](https://github.com/fredrikaverpil/neotest-golang/commit/b9cc68c9bcb8465122460addb25b2b1df0bbb0cb))

## [0.7.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.6.1...v0.7.0) (2024-07-13)


### Features

* add healthcheck ([#123](https://github.com/fredrikaverpil/neotest-golang/issues/123)) ([2e34efd](https://github.com/fredrikaverpil/neotest-golang/commit/2e34efdee206bc9830cd387e3f26e4531fb1e19a))


### Bug Fixes

* discussion form ([#125](https://github.com/fredrikaverpil/neotest-golang/issues/125)) ([ef0d561](https://github.com/fredrikaverpil/neotest-golang/commit/ef0d561686d57069f712d460a11dfc3d8012626a))
* improve discussions form further ([#127](https://github.com/fredrikaverpil/neotest-golang/issues/127)) ([b63ff72](https://github.com/fredrikaverpil/neotest-golang/commit/b63ff721c9d8bca09aded7377e8e72167c8910d1))
* invalid discussion form (again) ([#126](https://github.com/fredrikaverpil/neotest-golang/issues/126)) ([a0cc974](https://github.com/fredrikaverpil/neotest-golang/commit/a0cc9746441f6a243b22e60689d477b19bff06cd))

## [0.6.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.6.0...v0.6.1) (2024-07-11)


### Bug Fixes

* remove dependency on 'find' executable ([#112](https://github.com/fredrikaverpil/neotest-golang/issues/112)) ([885baab](https://github.com/fredrikaverpil/neotest-golang/commit/885baab15ad240e318d25c24e3544cfb26e44110))
* runspec for dir/file did not properly detect go package ([#110](https://github.com/fredrikaverpil/neotest-golang/issues/110)) ([c9c5e33](https://github.com/fredrikaverpil/neotest-golang/commit/c9c5e33186b8c4c1e94cdbad4d496b2411af8381))

## [0.6.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.5.2...v0.6.0) (2024-07-11)


### Features

* testify test suite support ([#58](https://github.com/fredrikaverpil/neotest-golang/issues/58)) ([d723241](https://github.com/fredrikaverpil/neotest-golang/commit/d723241f49c3413ec9fc6a5be20aa3410b345834))

## [0.5.2](https://github.com/fredrikaverpil/neotest-golang/compare/v0.5.1...v0.5.2) (2024-07-08)


### Bug Fixes

* search for go.mod up until home folder ([#104](https://github.com/fredrikaverpil/neotest-golang/issues/104)) ([7ec910c](https://github.com/fredrikaverpil/neotest-golang/commit/7ec910c0f2a1a1a2294d700ad81e70fcd2e97739))

## [0.5.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.5.0...v0.5.1) (2024-07-05)


### Bug Fixes

* escape regex characters in test name ([#96](https://github.com/fredrikaverpil/neotest-golang/issues/96)) ([a9042b6](https://github.com/fredrikaverpil/neotest-golang/commit/a9042b6a601c4123c9f84de5df113cd46735dac3))

## [0.5.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.4.0...v0.5.0) (2024-07-05)


### Features

* run all tests in file with one 'go test' command ([#92](https://github.com/fredrikaverpil/neotest-golang/issues/92)) ([535d695](https://github.com/fredrikaverpil/neotest-golang/commit/535d695657d445624b0d139291af649972fc7c21))

## [0.4.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.3.1...v0.4.0) (2024-07-03)


### Features

* experimental gotestsum support and larger refactoring ([#81](https://github.com/fredrikaverpil/neotest-golang/issues/81)) ([8672472](https://github.com/fredrikaverpil/neotest-golang/commit/8672472905cee881a376344ca065ee9628639403))


### Bug Fixes

* dap error ([#88](https://github.com/fredrikaverpil/neotest-golang/issues/88)) ([d9b0bb2](https://github.com/fredrikaverpil/neotest-golang/commit/d9b0bb2e974294d3f016ba1b4ed62bdd618974ce))

## [0.3.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.3.0...v0.3.1) (2024-07-03)


### Bug Fixes

* remove test suite AST-detection (still in POC) ([#85](https://github.com/fredrikaverpil/neotest-golang/issues/85)) ([3766f89](https://github.com/fredrikaverpil/neotest-golang/commit/3766f899de542195ac1d8d0299f6979a15457d20))

## [0.3.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.2.0...v0.3.0) (2024-07-03)


### Features

* core test output parsing ([#82](https://github.com/fredrikaverpil/neotest-golang/issues/82)) ([e4d8020](https://github.com/fredrikaverpil/neotest-golang/commit/e4d8020a9df2883f0cf417d37aaf79a0759a4473)), closes [#4](https://github.com/fredrikaverpil/neotest-golang/issues/4)

## [0.2.0](https://github.com/fredrikaverpil/neotest-golang/compare/v0.1.2...v0.2.0) (2024-06-29)


### Features

* support table tests defined in for loop ([#71](https://github.com/fredrikaverpil/neotest-golang/issues/71)) ([5d13357](https://github.com/fredrikaverpil/neotest-golang/commit/5d1335746d8975f736ce3ca9a9eec72a1412c39d))


### Bug Fixes

* do not allow test skipping ([#72](https://github.com/fredrikaverpil/neotest-golang/issues/72)) ([8973d54](https://github.com/fredrikaverpil/neotest-golang/commit/8973d5449fbcfa32fd2b786cded748450b188844))
* regexp character escaping ([#70](https://github.com/fredrikaverpil/neotest-golang/issues/70)) ([37f8877](https://github.com/fredrikaverpil/neotest-golang/commit/37f887739ace41810dcd1a10cb2d650c5524831f))

## [0.1.2](https://github.com/fredrikaverpil/neotest-golang/compare/v0.1.1...v0.1.2) (2024-06-28)


### Bug Fixes

* escaping of []{} brackets were missing ([#64](https://github.com/fredrikaverpil/neotest-golang/issues/64)) ([2dcc9e9](https://github.com/fredrikaverpil/neotest-golang/commit/2dcc9e90d2d72b9d9ff41260b4dba1a319c369e6))
* options not returned ([#63](https://github.com/fredrikaverpil/neotest-golang/issues/63)) ([18c31a9](https://github.com/fredrikaverpil/neotest-golang/commit/18c31a9373198a45397e2d6afa091390707c5e5c))

## [0.1.1](https://github.com/fredrikaverpil/neotest-golang/compare/v0.1.0...v0.1.1) (2024-06-25)


### Bug Fixes

* remove timeout from default args ([#56](https://github.com/fredrikaverpil/neotest-golang/issues/56)) ([b3821da](https://github.com/fredrikaverpil/neotest-golang/commit/b3821daa8ca276bba9688740d5393f9f4d517642))

## 0.1.0 (2024-06-24)

Initial release.
