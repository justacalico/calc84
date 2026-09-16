# Repo standards

This project is kept at an A+ grade. Keep it that way when making changes.

## Non-negotiables

- `flutter analyze` reports zero issues.
- `flutter test` passes every test.
- `flutter test --coverage` keeps line coverage of `lib/` at 100%.
- No TODOs, stubs, or placeholder implementations. Every key, menu, and
  screen on the keypad works.
- No god files. Engine, model, state, and UI stay in separate layers.

## Architecture

- `lib/engine` - pure Dart math: tokenizer, parser, evaluator, functions,
  TI-BASIC interpreter, TVM solver, calculus, distributions, regressions.
  No Flutter imports allowed here.
- `lib/model` - key map, screen definitions, settings, entry-line model.
- `lib/state` - calculator state machine and graphing controller.
- `lib/ui` - shell, keypad, LCD painters, theme. Rendering only.

## Hardware fidelity

- Match the real TI-84 Plus CE, including error codes, edge cases, and
  quirks. When in doubt, check what the physical device does.
- Lists are real-only, `rand(n)` returns a list, `-0.5!` uses gamma
  reflection, and `2nd`/`alpha` modifiers behave like the hardware.

## Commits and tests

- Write a test with every behavior change; never merge a failing suite.
- Keep diffs focused: one concern per change.
- If you remove dead code, delete it fully rather than commenting it out.
