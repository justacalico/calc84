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
  BASIC interpreter, TVM solver, calculus, distributions, regressions.
  No Flutter imports allowed here.
- `lib/model` - key map, screen definitions, settings, entry-line model.
- `lib/state` - calculator state machine and graphing controller.
- `lib/ui` - shell, keypad, LCD painters, theme. Rendering only.

## Hardware fidelity

- Match the real calculator, including error codes, edge cases, and
  quirks. When in doubt, check what the physical device does.
- Lists are real-only, `rand(n)` returns a list, `-0.5!` uses gamma
  reflection, and `2nd`/`alpha` modifiers behave like the hardware.

## Commits and tests

- Write a test with every behavior change; never merge a failing suite.
- Keep diffs focused: one concern per change.
- If you remove dead code, delete it fully rather than commenting it out.
- Commit subjects follow Conventional Commits so cocogitto can bump
  versions: `<type>: <description>` where the type is English
  (`feat`, `fix`, `chore`, `ci`, `docs`, `refactor`, `style`, `test`,
  `perf`, `revert`, `build`, `misc`) and the description is Chinese.
  Run `git config core.hooksPath .githooks` once so non-conventional
  subjects are auto-prefixed with `misc:`.
- Releases are automatic. A `feat`/`fix`/`perf`/`revert` commit merged to
  `main` makes cocogitto bump `pubspec.yaml`, tag `vX.Y.Z`, and ship a
  full platform release through GitHub Actions back to GitLab.

## Release pipeline

- GitLab is the source of truth. `github-sync` mirrors `main` and tags to
  `github.com/justacalico/calc84`.
- `.github/workflows/build.yml` builds android, linux (x86_64+arm64:
  zip/deb/rpm/tar.gz), windows (x86_64+arm64), macOS arm64, and an
  unsigned iOS ipa, then publishes a GitHub release.
- `github-release-sync` mirrors the GitHub release assets into a GitLab
  release on the same tag.
- Android signing comes from `key.properties` + `upload-keystore.jks`,
  which are gitignored and injected from GitHub secrets. Never commit
  keystores or credentials.
