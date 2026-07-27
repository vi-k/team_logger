## 0.4.0

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
