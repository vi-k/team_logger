## 0.7.0

- [breaking changes] Empty custom file-session ids are now rejected with
  `ArgumentError` instead of creating chunk files that session listing cannot
  discover. Chunk names whose numeric index does not fit in a Dart `int` are
  treated as foreign files instead of disabling listing or storage startup.
- [breaking changes] `Log.tags` and `Log.traceIds` are now unmodifiable
  snapshots. Mutating collections passed to the public constructor or as
  `copyWith()` replacements no longer changes an existing log, and attempts
  to mutate the exposed collections throw `UnsupportedError`. The normal
  `Logger` path transfers fresh collections without copying their elements;
  `copyWith()` reuses snapshots when those fields are omitted.
- [breaking changes] `Loggable.objectToJson()` now throws `ArgumentError` when
  distinct emitted map keys have the same JSON representation, such as `1`
  and `'1'`, instead of silently keeping the later value. Affected
  `FileLogStorage` JSON records use the existing `encodeError` fallback and
  report the original error through `onError` without losing batch neighbors.
- [breaking changes] Replace `FileLogSessions.archiveTo()` with streaming
  `gzipTo()`. It writes the selected sessions, in order and with each session's
  metadata line, into one GZIP-compressed JSON Lines file instead of a ZIP
  containing one file per session. Memory use is now bounded by I/O and
  compression buffers rather than the complete source set plus the output
  archive. Targets that alias selected chunks are rejected before writing,
  and source read failures are not masked by output cleanup. The `archive`
  package is no longer a dependency.
- [breaking changes] `FileLogStorage.flush()` and `close()` no longer report
  success after an initialization or write failure made an accepted log
  unavailable. The affected logs go to `onDropped`; both lifecycle methods
  drain or close resources and then complete with the first durability error,
  which remains sticky for that storage instance. `onError` still receives
  the original failure when it happens.
- `FileLogStorage.minLevel` is now applied before the bounded queue, so logs
  excluded from file output neither consume queue capacity nor displace an
  eligible log into `onDropped`.
- Fixed best-effort handling of accidental or pre-existing chunk symlinks in
  an application-private, trusted log directory: they are ignored rather than
  making reading or appending leave it. This is not a sandbox against a
  concurrent hostile actor that can race filesystem operations.
- Fixed immediate `close()` so it waits for initialization and the active
  chunk handle to close. `isClosed` now flips synchronously, and `flush()`
  called after closing starts returns the exact same full-lifecycle Future.
- Documented and tested the supported current-session deletion sequence:
  deleting it while its `FileLogStorage` is active is unsupported; await
  `close()` first.
- Clarified the existing file-retention contract: `maxChunkSize` and
  `maxSessionSize` are rotation and retention targets, while `maxTotalSize`
  is a startup retention budget. JSON Lines records stay whole and the newest
  chunk is always retained, so one oversized record can exceed all three
  settings; callers that need a hard disk ceiling must bound their inputs.
- `BbCodeFormatter` no longer uses a backtracking regular expression: a
  single left-to-right scan now keeps malformed input from blocking the
  isolate. Properly nested tags, including identical tags, are supported;
  mismatched closing tags stay literal instead of closing an earlier tag.
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
- [breaking changes] Require `logger_builder` ^0.7.0, up from ^0.5.0 (the
  changes flow through the re-export). The one that changes behaviour of
  code written against this package is publisher inheritance:
  `child[level].publisher = ...` now pins that one level and leaves the
  others following the parent, where before the coarse linked flag cut the
  whole sublogger — and everything under it — off the parent for good.
  That was a documented limitation here; it is gone. `publisherLinked`
  therefore stays `true` in cases that used to clear it, a common
  `logger.publisher = ...` no longer overwrites a pinned level (so the
  order of the two assignments stopped mattering), a linked sublogger
  takes the parent's publisher *for that level* instead of flattening the
  parent's exceptions, and `relink()` drops every pin rather than the
  logger's own links. There is no idiom left for detaching all levels
  without changing a value —
  `child[level].publisher = child[level].publisher` now pins the level
  instead — and `hasPublisher` can consequently go back to `false` on a
  level that once had a real publisher: read it as "publishes somewhere
  right now", which is what it says.
- [breaking changes] The queue behind [FileLogStorage] is bounded now,
  because the base class it is built on bounds every asynchronous queue:
  `maxQueueSize` defaults to 100 000 logs accepted and not yet written. At
  the limit it is the *incoming* log that is refused, so a disk that
  cannot keep up costs the newest logs rather than the process, and
  everything already accepted is still written — `flush()` and `close()`
  promise what they promised before. Before this, an unwritable directory
  grew the queue until memory ran out.
- [FileLogStorage] takes `onDropped` and `maxQueueSize` and hands both to
  the base class. A refused log reaches `onDropped` as a one-element batch
  — the callback takes a list, the same one a spent retry budget would
  hand it; with no handler set, the loss is announced on stdout rather
  than hidden — the first one at once and the rest as a count, at most
  once every five seconds — so pass `onDropped: (_) {}` for a storage that
  must stay quiet. This is the only way a log is lost after being
  accepted: a failed write is reported to `onError` and never retried, so
  the retry budget of the base class (`maxRetries`, `retryDelay`) never
  comes into play here and neither knob is exposed.
- Also from that upgrade, from the 0.6.x part of it: a transformer that
  logs through its own logger is caught by a reentrancy guard — the nested
  log is dropped and a [StateError] is reported — where before the call
  recursed into a `StackOverflowError`; the dartdoc on [Logger] said the
  old thing and now says this one. A level logger is rejected at a
  threshold (`Levels.all`/`Levels.off`), registering one level logger in
  two loggers throws, `TransformPublisher.close()` is terminal and
  idempotent, and a sublogger holds its parent strongly, so an
  intermediate logger nobody kept no longer stops passing
  `level`/`publisher` changes down.
- New from that upgrade, without any work here: `CustomLogger.onError` —
  one hook for a throwing transformer, a reentrancy violation and a
  throwing publisher, resolved through the parent chain — plus
  `CustomLevelLogger.hasPublisher`, its new companion `hasOwnPublisher`
  (a pinned level against one that takes its publisher from above) and a
  per-level `relink()` that drops the pin and takes from the chain again.
  `LevelLogger` declares neither name, so nothing here silently overrides
  them.
- That upgrade also carries the fixes that matter most under this package:
  `flush()` during a `close()` returns the close instead of a false
  all-clear, `close()` no longer sleeps through a pending retry, a failing
  sink no longer starves the event loop, a buffered publisher reports
  handler errors into the zone that *built* it rather than whichever scope
  logged first, registering a sublogger from inside `processLog` no longer
  throws a `ConcurrentModificationError`, a `CustomLogger.onError` handler
  that logs no longer recurses until the stack is gone, and `TypedLazy`
  memoizes a throwing `convert` — which is what [Logger] resolves a
  namespace path and a lazy message through.
- The package installs into a Flutter application again, from Flutter 3.27
  — the line that carries Dart 3.6, the floor this package declares. It
  did not: Flutter pins several packages to an *exact* version out of its
  own SDK, so a floor above such a pin is a version-solving failure rather
  than a newer resolve. `clock`, `meta` and `stack_trace` now sit at the
  3.27 pins (^1.1.1, ^1.15.0, ^1.12.0) instead of the 3.29 ones, and
  nothing here needs anything newer.
- [breaking changes] Require `format` ^4.1.0, up from ^1.6.0, which is what
  made the above possible one level down. 1.6.0 wanted `characters` ^1.4.0
  where Flutter 3.27 pins 1.3.0, and `intl` ^0.20.2 where
  `flutter_localizations` pins 0.19.0 on both 3.27 and 3.29 — a localized
  application could not take this package at all on those lines. `format`
  4.1.0 lowered its own floor to Dart ^3.6.0 and has had no `intl`
  dependency since 3.0.0, so `intl` leaves the dependency graph of every
  application that takes this package. One rendering moves with the
  upgrade: `doubleFormat: 'g'` prints `1234.5678` for 1234.5678 where the
  1.x branch printed `1234.57`. Everything else — padding, grouping,
  radices, fixed and exponential forms, rounding — is unchanged, and
  `test/loggable/number_format_test.dart` now pins all of it; that file
  covers `intFormat`/`doubleFormat` for the first time.
- [breaking changes] `format` is no longer a dependency of this package,
  and number formatting is a theme's job. `intFormat` and `doubleFormat`
  keep their names and their `String?` type, but the package no longer
  reads them: the string goes to [LogMainTheme.numberFormatter] together
  with the value, and what it means is that formatter's business. A theme
  without one prints the number as it is — no exception, and no pattern
  applied, where an invalid specifier used to throw from inside `format`
  at the logging call site. Two changes to make on the way up: install the
  formatter — `numberFormatter: (theme, value, pattern) =>
  format(pattern, value)`, with `format` in your own pubspec — and write
  the whole template where a bare specifier used to go, `'{:,d}'` for
  `',d'` and `'{:.4f}'` for `'.4f'`. Nothing else here took `format`, so
  it leaves the dependency graph of every application that takes this
  package; a formatter over `sprintf` (`'%d'` in the config then), or one
  with nothing to do with `format` at all, is now equally installable.
- [breaking changes] A locale-aware `intFormat`/`doubleFormat` no longer
  works by setting `Intl.defaultLocale`, because the specifier is handed
  to `format` and `format` stopped reading an ambient `intl` locale when
  it dropped the dependency. `intFormat: ',n'` now throws
  `InvalidSpecifierException` outright — `n` takes no grouping option —
  and a bare `n` follows the C locale rather than the application's. The
  README taught the old form and no longer does: the example that printed
  123 456 789 in Bengali digits prints it in hexadecimal instead
  (`intFormat: '#x'`), and `intl` leaves `example/` with it. There is no
  replacement for the locale-aware form here: `format` reads its
  `NumberLocale` from a `Format` instance, and this package calls the
  top-level `format()`.
- The example package is one example again. `example/example.dart` is a
  single request through the logger — a namespace sublogger with a tag, a
  trace id across an async flow, a request as headers and body, a response
  object that prints itself, a redacted header, a failure with its stack
  trace — and it is what pub.dev shows on the Example tab, where the
  `dart create` boilerplate used to be. The 288-line "print everything"
  program that lived there has moved to `tool/` and is not published; the
  per-section code behind the README screenshots stays where it was.

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
