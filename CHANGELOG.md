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
  formatting ([StackOverflowError]); [BbCodeFormatter] no longer truncates
  messages; single-character messages are printed; a tail wider than
  [maxLength] no longer drops the log line; truncation/wrapping is
  surrogate-safe; fillers show no ellipsis; stack trace frames wrap
  instead of losing the file name; [LogStorage] edge cases (maxCount 0,
  publish after dispose, reversed.reversed, growable snapshot); tags
  accept any iterable; collection length budgets include the ellipsis;
  [ControlCodeFormatter] no longer leaks a bare ANSI reset; [LogTime]
  column width no longer jitters with microseconds; [LoggableView] (null),
  [fixed] and duplicate props are consistent between string and JSON
  output; user map keys starting with ':' are escaped; [LogTags] prints
  nothing when there are no tags.
- [breaking changes] Rename [collectionMaxLength] to [collectionMaxCount].
- [Loggable.efficientLengthIterableToString] and [Loggable.iterableToString]
  now accept the parameter [collectionMaxCount] = 0.
- Add [Loggable.objectToJson].
- Add [LoggableData.round].
- Add file-based session log storage (`package:team_logger/team_logger_io.dart`):
  [FileLogStorage] writes logs to per-session JSON Lines files with chunk
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
