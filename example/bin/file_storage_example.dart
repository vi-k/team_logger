import 'dart:io';

import 'package:team_logger/team_logger_io.dart';

final storage = FileLogStorage(
  directory: '${Directory.systemTemp.path}/team_logger_example',
  meta: {'appVersion': '1.2.3', 'device': 'example'},
  maxTotalSize: 10 * 1024 * 1024,
  maxSessionSize: 1024 * 1024,
  maxChunkSize: 128 * 1024,
  maxAge: const Duration(days: 7),
);

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = MultiPublisher([
    ConsoleLogPrinter(
      theme: LogMainTheme.defaultActiveTheme,
      rows: const [
        LogRow(
          maxLength: 120,
          children: [
            LogNum(),
            LogLevelName.short(),
            LogTime.onlyTime(),
            LogPath(),
            LogMessage(),
          ],
        ),
      ],
    ),
    storage,
  ]);

Future<void> main() async {
  log.i('Application started');
  log.d('Loading config', data: {'path': '/etc/app.conf', 'timeout': 30});
  log.w('Cache is stale');
  log.e(
    'Request failed',
    error: Exception('Connection refused'),
    stackTrace: StackTrace.current,
  );

  // Everything published is guaranteed to be on disk after flush.
  await storage.flush();

  // The sessions in the directory, the current one included.
  final sessions = await storage.sessions.list();
  for (final session in sessions) {
    final current = session.id == storage.sessionId ? ' (current)' : '';
    log.i(
      'Session ${session.id}$current',
      data: {
        'size': session.size,
        'lastModified': session.lastModified,
        'meta': await session.readMeta(),
      },
    );
  }

  // One streamed GZIP for every session; their meta lines mark the
  // boundaries.
  final gzipFile =
      File('${storage.directory}/../team_logger_example_logs.jsonl.gz');
  await storage.sessions.gzipTo(gzipFile);
  log.i(
    'Logs compressed',
    data: {'path': gzipFile.path, 'size': gzipFile.lengthSync()},
  );

  await storage.close();
}
