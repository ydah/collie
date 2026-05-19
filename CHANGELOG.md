# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.0.0 - 2026-05-20

### Added

- Added stable `collie lint`, `collie fmt`, `collie rules`, and `collie version` CLI workflows for Lrama-style grammar files.
- Added `collie explain` for rule metadata, `collie init` for generating profile-based configuration, and `collie config-schema` for editor/tooling integration.
- Added parser debug commands, `collie tokens` and `collie ast`, with JSON output.
- Added stdin support for linting and formatting with `--stdin` and `--stdin-filename`.
- Added SARIF output for code scanning, alongside text, JSON, and GitHub Actions annotation reporters.
- Added lint coverage for symbol conflicts, duplicate precedence declarations, non-productive grammar cycles, Lrama declarations, inline rule dependencies, and precedence declarations used as tokens.

### Changed

- Expanded file target handling so `lint` and `fmt` can accept directories and glob patterns.
- Improved formatter preservation for comments, unknown directive blocks, declaration order, parameterless rule declarations, and grammar structure.
- Made formatter layout options configurable and verified formatted output by reparsing it before writing.
- Improved CLI failure behavior for CI, including parse errors as diagnostics and configurable `--fail-level` thresholds.
- Made rule filtering stricter by validating unknown `--only` and `--except` rule names before running lint checks.
- Reflected configured rule enablement and severity in `collie rules --format json`.

### Fixed

- Fixed repeated `--only` and `--except` handling so rule filters do not consume positional file arguments.
- Fixed config loading errors for missing, invalid, inherited, and non-mapping YAML files.
- Fixed autocorrection so one correction does not clobber changes made by another correction.
- Reduced false positives in right-recursion and unused-rule diagnostics for LR grammar workflows.

## 0.1.0 - 2025-12-17

- Initial commit
