## 0.7.0

- [breaking changes] A root-position rule (`ctx.depth == 0`) now also
  applies to a plain `toString()`: `'$obj'` and `print(obj)` for a
  [Loggable] or [LoggableData] go through the sanitizer, where before only
  their properties did. Everything the library renders outside the
  sanitizer's documented scope — the message, the error, the stack trace,
  the tags and the namespace path — is explicitly kept out of it, so a
  rule can no longer erase an error or rewrite the cached [Log.tags] that
  `activeTags` filters on.
- [breaking changes] A replacement no longer inherits `units` anywhere:
  units describe the original quantity and a mask is not it. Properties
  already behaved this way; the root now matches. The rest of a
  container's config (`collectionMaxCount` and friends) is still
  inherited, since that describes how to print rather than what the value
  is.
- Two leaks found by a two-reviewer cross-review of 0.6.0 are closed. The
  console printer and the public [LoggableMultiData.toString] rendered
  multi-data sections themselves and never offered the ROOT value, so a
  root-level rule was honoured in JSONL files and silently ignored on the
  console. And a `view` that re-enters the walkers (a raw
  [Loggable]/[LoggableWrapper], or a [LoggableView] converter that
  renders) restarted at an empty path, so a path-based rule both missed it
  and could over-redact an unrelated top-level property of the same name.
- A [Map] key is now rendered once instead of twice. It used to be
  rendered a first time to derive `ctx.name` and a second time for the
  output, the two firing the rule at different paths — and the printed one
  was the unsanitized second. The derivation also ran with no sanitizer
  installed, doubling `toString()` calls and breaking a key whose
  `toString()` throws; that path is back to its 0.5.2 behaviour.
- A rule that throws no longer persists what it refused: [FileLogStorage]
  writes only the error TYPE into the fallback line (`ArgumentError.value`
  puts the offending value into the message, and the file is where it must
  not end up). The full error still reaches `onError`.
- `collectionMaxCount` no longer offers the element it then discards;
  [LoggableData.toJson] no longer allocates a sanitizer-only list when no
  rule is installed; the printer and the file codec decide on an exact
  dropped signal instead of inferring one from an empty rendering, so data
  that legitimately renders empty keeps its colon while a multi-data whose
  sections were all dropped prints no data block at all.
- Documented boundaries that 0.6.0 stated too broadly: a [Map] key is not
  offered to the rule (its contents are, but only where the key's
  rendering enters the walkers, and under the container's path); for a
  non-`String` key `ctx.name` is the key as that particular output renders
  it, so such entries are redacted by value rather than by key text; a
  [Prop] rendered on its own prints `'<dropped>'`, having no container to
  remove it from.
- [breaking changes] Require `ansi_escape_codes` ^4.0.1, up from ^3.1.2.
  Its 530 top-level style constants are gone: the table is one class now,
  so a theme written as `ansi.rgb030` is written `Styles.rgb030`, and
  `ansi.bold` is `Styles.bold`. The names this package hands on are
  otherwise unchanged, and `Styles` is re-exported beside [Style],
  [NoStyle], [Color16] and [Color256] — a theme needs no direct dependency
  on the package that defines them. Code that reaches into
  `ansi_escape_codes` directly for other reasons also loses the `parsing`
  entry point (`style.dart` carries the same names), and finds `Match` as
  `Piece`, `Link` as `OscLink` and `rgb`/`gray` as `rgb256`/`gray256`; see
  its own changelog for the rest.
- [breaking changes] Require `logger_builder` ^0.6.1, up from ^0.5.0 (the
  changes flow through the re-export). A transformer that logs through its
  own logger is now caught by a reentrancy guard — the nested log is
  dropped and a [StateError] is reported — where before the call recursed
  into a `StackOverflowError`; the dartdoc on [Logger] said the old thing
  and now says this one. A level logger is rejected at a threshold
  (`Levels.all`/`Levels.off`), registering one level logger in two loggers
  throws, `TransformPublisher.close()` is terminal and idempotent, and a
  sublogger holds its parent strongly, so an intermediate logger nobody
  kept no longer stops passing `level`/`publisher` changes down.
- New from that upgrade, without any work here: `CustomLogger.onError` —
  one hook for a throwing transformer, a reentrancy violation and a
  throwing publisher, resolved through the parent chain — plus
  `CustomLevelLogger.hasPublisher`, `AsyncPublisherWithBufferBase.onDropped`
  and a `retryDelay` on the buffered publishers [FileLogStorage] is built
  on. That upgrade also carries the buffered-publisher fixes that matter
  most to file storage: `flush()` during a `close()` returns the close
  instead of a false all-clear, `close()` no longer sleeps through a
  pending retry, and a failing sink no longer starves the event loop.
- The package installs into a Flutter application again, from Flutter 3.27
  — the line that carries Dart 3.6, the floor this package declares. It
  did not: Flutter pins several packages to an *exact* version out of its
  own SDK, so a floor above such a pin is a version-solving failure rather
  than a newer resolve. `clock`, `meta` and `stack_trace` now sit at the
  3.27 pins (^1.1.1, ^1.15.0, ^1.12.0) instead of the 3.29 ones, and
  nothing here needs anything newer.
- `format` is `>=1.5.2 <2.0.0` instead of `^1.6.0`, for the same reason one
  level down: 1.6.0 wants `characters` ^1.4.0 where Flutter 3.27 pins
  1.3.0, and `intl` ^0.20.2 where `flutter_localizations` pins 0.19.0 on
  both 3.27 and 3.29 — a localized application could not take this package
  at all on those. Which of 1.5.2 and 1.6.0 an application resolves is now
  its own SDK's business, and `test/loggable/number_format_test.dart` pins
  `intFormat`/`doubleFormat` output on both so the branch cannot change
  what a log looks like. The upper bound is deliberate: `format` 3.0.0 and
  4.0.0 raise their own floor to Dart ^3.7.2 (Flutter 3.29.2), and they
  render `{:g}` as `1234.5678` where 1.x renders `1234.57`.

## 0.6.0

- Per-value sanitization of logged data: assign [Loggable.sanitizer] to
  process every value on its way to the output. The callback receives a
  [SanitizeContext] (name, value, a lazily built path such as
  `user.card.number`, depth) and returns the value unchanged, a
  replacement, or [Sanitize.drop] to remove the property/entry from the
  output entirely. The hook is global, so it cannot be forgotten on a
  publisher: it applies to the console printer, file storage, session
  export and any direct [Loggable.objectToString]/[objectToJson] call —
  including an in-app log viewer.
- A replacement is rendered as a plain value: the original's children are
  no longer offered to the rule, but the replacement's own children are,
  normally — a rule whose replacement itself matches the same rule
  recurses forever. A property's `view` is what the rule sees, not the
  text it renders (no [LoggableView] goes through the walkers), so such a
  property must be redacted by `name`/`path`, not by matching rendered
  content. In a collection-element position [Sanitize.drop] renders
  `'<dropped>'` rather than removing the element, so the printed
  collection length stays honest.
- The rule must be free of side effects and must neither render nor log
  from inside itself — [Loggable.sanitizer] is a per-isolate static, so
  set it again in any isolate you spawn. Cycle protection, collection
  limits and lazy iterables are unaffected: sanitization happens while
  rendering, so filtered-out logs still cost nothing. The raw value still
  lives in [Log.data]; reach for [Logger.transformer] when a value must
  not exist in memory at all.

## 0.5.2

- Pre-publication log processing (primarily for security — masking
  secrets/PII, dropping forbidden logs): require `logger_builder` ^0.5.0,
  whose new API flows through the re-export. Assign
  [Logger.transformer] (`Log? Function(Log)`) to process every log right
  before publishing — subloggers inherit it like `level`/`publisher`;
  returning `null` drops the log. Wrap a single publisher in
  [TransformPublisher] to transform for one destination only. Fail-closed:
  a throwing transformer drops the log and reports the error to
  `onError`/the current zone — the untransformed log is never published.
- Add [Log.copyWith] — the building block for transformers: replaces
  message/data/tags/error/stackTrace/path/traceIds while always preserving
  the log's identity ([Log.num], [Log.time], the level and zone; no new
  sequence number is consumed). `copyWith(error: null)` clears the error,
  `data: Log.noData` clears the data.

## 0.5.1

- Internal: [FileLogStorage] drops its pending-log counter and the
  `flush()` fast path — workarounds for the `flush()` hang of
  logger_builder <= 0.3.2. `flush()` now awaits initialization and relies
  on the drain semantics of the base class; the guarantees are unchanged
  (initialization completed, everything published is on disk).

## 0.5.0

- [breaking changes] Require `logger_builder` ^0.4.0 (the changes flow
  through the re-export): `HasFlush` is renamed to [Flushable] (the old
  name remains as a deprecated alias), the new [Closable] interface
  exposes `close()`, [MultiPublisher] gains a closed state and copies the
  publisher list at construction, [CustomLevelLogger] can no longer be
  implemented outside logger_builder, async publishers get `onError`,
  `isClosed` and non-hanging drain-semantics `flush()`. See the
  logger_builder 0.3.3/0.4.0 changelog for the full list.
- [FileLogStorage.onError] is now the inherited base-class callback: it
  additionally receives the write-pipeline errors of
  [AsyncPublisherWithBufferBase] (previously they were reported to the
  current zone).

## 0.4.2

- Require `logger_builder` ^0.3.2: an exception thrown by one publisher in
  [MultiPublisher] no longer interrupts publishing to the remaining
  publishers and no longer propagates to the logging call site. The new
  [MultiPublisher.onError] callback receives the failing publisher along
  with the error; without it, the error is reported to the current zone as
  an uncaught asynchronous error. [MultiPublisher.flush] now starts
  flushing all publishers even if one of them throws synchronously.

## 0.4.1

- [breaking changes] The `ansi_escape_codes` re-export is narrowed to
  `Style`, `NoStyle`, `Color16`, `Color256`: the full barrel leaked names
  clashing with Flutter (`Color`, `Colors`, `Stack`, `State`, `Text`).
  For the predefined style shortcuts (`rgb431`, ...) depend on
  `ansi_escape_codes` directly (ideally with an import prefix).

## 0.4.0

- [breaking changes] Rename [Log.sequenceNum] to [Log.num]
  ([lastSequenceNum] to [lastNum]).
- [breaking changes] Rename [LogSequenceNum] to [LogNum].
- [breaking changes] Rename [LogThemeData.sequenceNumStyle] to [numStyle].
- [breaking changes] Rename [LogStorage.indexBySequenceNum] to [indexByNum].
- [breaking changes] Rename [collectionShowLength] to [collectionShowCount]
  (in [LoggableConfig] and [LogMainTheme]).
- [breaking changes] Rename [LoggableResolvedConfig] to
  [LoggableEffectiveConfig], [LoggableConfig.resolved] to
  [toEffectiveConfig].
- [breaking changes] The [TypeProp] constructor is now private.
- Export [LoggableJsonConfig]; add [Prop.toMapEntry] and [Prop.toJson].
- [breaking changes] [LoggableTypeConverter] is reduced to [convertToData]:
  the [toJson]/[toLogString] members were never called by the library.
- [LoggableMultiView.toJson] now returns a structured object
  (`{":k": "multi-view", ":v": [...]}`) instead of a joined string.
- [breaking changes] Rename [Constraints] to [LogConstraints] (the old name
  clashed with the Flutter type).
- [breaking changes] [LogThemeData.copyWith] no longer accepts the phantom
  [colon]/[ellipsis]/[lineBreak]/[padding] parameters (they were silently
  ignored; the real fields live in [LogMainTheme]).
- [activeNamespaces] now matches child namespaces by prefix ('app'
  activates 'app/net' but not 'application');
  [ConsoleLogPrinter.pathSeparator] is configurable.
- The printer's minLevel gate takes the minimum of the active and inactive
  themes, so active logs are never suppressed harder than background ones.
- Add [LogMainTheme.ansiCodesEnabled]; colorless theme copies no longer
  leak ANSI codes. Default themes no longer stamp a '#log' tag.
- Level [LogTheme]s are cached per [LogMainTheme] (BbCode regex is no
  longer recompiled for every message).
- Re-export the `ansi_escape_codes` styles, so themes can be configured
  without a direct dependency.
- Fix a batch of review findings: cyclic structures no longer crash
  formatting ([StackOverflowError]) — a cycle is rendered as `↺ₙ`
  (N = levels up, configurable via
  [LogMainTheme.cycleFormatter]/[cycleStyle]) and as
  `{":k": "cycle", ":up": N}` in JSON; [BbCodeFormatter] no longer truncates
  messages; single-character messages are printed; a tail wider than
  [maxLength] no longer drops the log line; truncation/wrapping is
  surrogate-safe; fillers show no ellipsis; stack trace frames wrap
  instead of losing the file name; [LogStorage] edge cases (maxCount 0,
  publish after dispose, reversed.reversed, growable snapshot); tags
  accept any iterable; collection length budgets include the ellipsis;
  [ControlCodeFormatter] no longer leaks a bare ANSI reset; [LogTime]
  column width no longer jitters with microseconds; [LoggableView] (null)
  and duplicate props are consistent between string and JSON output;
  non-finite doubles (nan/inf) omit units in both outputs; user map keys
  starting with ':' are escaped; [LogTags] prints nothing when there are
  no tags.
- [breaking changes] Rename [collectionMaxLength] to [collectionMaxCount].
- [Loggable.efficientLengthIterableToString] and [Loggable.iterableToString]
  now accept the parameter [collectionMaxCount] = 0.
- Add [Loggable.objectToJson].
- Add [LoggableData.round].
- Add file-based session log storage
  (`package:team_logger/team_logger_io.dart`): [FileLogStorage] writes
  logs to per-session JSON Lines files with chunk
  rotation ([maxSessionSize]/[maxChunkSize]), startup cleanup ([maxAge],
  [maxTotalSize]) and a metadata line; [FileLogSessions]/[FileLogSession]
  list, read, delete, export sessions and pack them into a single ZIP
  archive ([archiveTo]).

## 0.3.0

- Update README.
- [breaking changes] Rename [activeLoggers] to [activeNamespaces].
- [breaking changes] Rename [activeLevel] to [activeMinLevel].
- [breaking changes] Remove [AnsiPair].
- Add [activeLevels].
- Fix minor bugs.

## 0.2.0-0.2.2

- Publish.

## 0.1.0-0.1.70

- Initial version.
