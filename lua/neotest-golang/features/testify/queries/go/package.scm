; ============================================================================
; RESPONSIBILITY: Package identification
; ============================================================================
; Detects the package name in Go files.
;
; Example:
;   package main  // @package captures "main"
;
; Used by lookup.lua to track package information when building the lookup
; table for testify suite mappings.
; ============================================================================
; query:
;
; package main  // @package
(package_clause
  (package_identifier) @package)
