# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`team_logger` is a pure Dart package (published on pub.dev) — a highly-configurable, trace-aware, structured logging library for large teams and high-volume logs. It has no Flutter dependency. Requires Dart SDK `^3.6.0`.

The `example/` directory is a separate Dart package (`publish_to: none`) with a path dependency on the root package. It also depends on `freezed`/`build_runner` for code generation and drives most of the README screenshots.

## Commands

Run from the repository root:

```bash
dart pub get                              # install deps
dart test                                 # run all tests
dart test test/team_logger_test.dart      # single file
dart test -n 'objectToJson'               # tests matching a name/group substring
dart analyze                              # static analysis (strict — see below)
dart format .                             # format
```

The example package has its own pubspec and must be run/analyzed from `example/`:

```bash
cd example && dart pub get
dart run bin/example.dart                 # main example
dart run build_runner build               # regenerate *.freezed.dart
```

`scripts/ansi_screenshot.sh` renders ANSI console output to the PNGs in `screenshots/` used by the README.

## Analysis is strict

`analysis_options.yaml` extends `package:lints/recommended` and turns on `strict-casts`, `strict-inference`, `strict-raw-types`, plus a large hand-curated linter set. Notable enforced rules: `prefer_single_quotes`, `require_trailing_commas`, `prefer_const_constructors`, `omit_local_variable_types`, `avoid_final_parameters`, `cascade_invocations`, `sort_pub_dependencies`, and `unreachable_from_main` (dead top-level code is flagged). New code must satisfy these — run `dart analyze` before considering work done.

## Architecture

The library builds on the `logger_builder` package, which supplies the abstract base classes (`CustomLogger`, `CustomLevelLogger`, `CustomLog`, `CustomLogPublisher`) and the lazy primitives (`Lazy`, `LazyString`, `TypedLazy`). `lib/team_logger.dart` re-exports all of `logger_builder` plus the `src/` public API, so a single import gives users everything.

The pipeline is: **Logger → Log → Publisher (Printer or Storage)**.

- **`src/logger/`** — `Logger` is a namespace logger. `createChild(name:)` builds path hierarchies (`app/network`), `copyWith` clones without extending the path. Each `Logger` registers six `LevelLogger`s (verbose/debug/info/warning/error/critical, exposed as `log.v`/`log.d`/…). Calling a level builds a `Log` (`log.dart`, a `part of logger.dart`) — an immutable record carrying sequence number, timestamp, path, message, resolved `data`, tags, trace IDs, error/stackTrace — and hands it to `publisher.publish(...)`. Messages and data are resolved lazily, so filtered-out logs cost nothing.

- **Trace propagation** — `log.trace(TraceId, fn)` runs `fn` inside a Dart `Zone` whose zone-values accumulate trace IDs and tags. Any log emitted within that async scope automatically picks them up via `Logger.zonedTraceIds`/`zonedTags`. This is the core "no manual context passing" feature.

- **`src/loggable/`** — the object-formatting system. `Loggable` is a mixin: a class implements `collectLoggableData(LoggableData)` to declare its properties (`.prop(...)`, `.hidden(...)`, units, number formats, collection limits). `Loggable.from(obj, config:)` wraps arbitrary values; `Loggable.builder(obj)` formats classes that can't implement the mixin; type converters can be registered for third-party types. Two output targets: `objectToString` (console) and `objectToJson` (structured). `LoggableConfig` / `LoggableJsonConfig` control formatting. Comments in this subtree are in Russian.

- **`src/printer/`** — `ConsoleLogPrinter` is the main publisher. Output layout is data-driven: you pass `rows: [LogRow(children: [...], tail: [...])]` where each child is a `LogElement` (`LogNum`, `LogLevelName`, `LogTime`, `LogPath`, `LogTraceId`, `LogMessage`, `LogTags`, `LogDivider`, `LogCustomText`, …). The printer supports **active vs. inactive** styling: pass `inactiveTheme` plus filters (`activeLevels`/`activeMinLevel`, `activeNamespaces`, `activeTraceGroups`, `activeTags`, or `isLogActive`) to dim background logs while emphasizing matching ones. `output` defaults to `print` but is injectable.

- **`src/preformatters/`** — message text preprocessing. `BbCodeFormatter` compiles inline BBCode (`[b]…[/b]`, `[success]…[/success]`) to ANSI; `ControlCodeFormatter`, `NullFormatter`, and the `MultiLogPreFormatter` compose these.

- **`src/theme/`** — `LogMainTheme` (with `defaultActiveTheme`) and `LogTheme`/`LogStyle`/`LogStyles` define ANSI styling per element, including depth-based bracket coloring.

- **`src/storage/`** — `LogStorage` is an alternative `CustomLogPublisher`: an in-memory circular buffer (`maxCount`, `minLevel`) exposing `onChanged` events for in-app log inspection/export.

## Conventions

- Naming has churned across recent versions (see `CHANGELOG.md`): `activeLoggers`→`activeNamespaces`, `activeLevel`→`activeMinLevel`, `collectionMaxLength`→`collectionMaxCount`, `LogStyle`↔`LogStyles`. When touching public API, check the changelog and update it — this package uses breaking-change version bumps.
- `TODO.md` tracks pending work (partly in Russian).
