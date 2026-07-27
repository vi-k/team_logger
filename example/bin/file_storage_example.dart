import 'dart:io';

import 'package:team_logger/team_logger_io.dart';

final storage = FileLogStorage(
  directory: '${Directory.systemTemp.path}/team_logger_example',
  meta: {'appVersion': '1.2.3', 'device': 'example'},
  maxSessionSize: 1024 * 1024,
  maxChunkSize: 128 * 1024,
  maxTotalSize: 10 * 1024 * 1024,
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

  // Всё, что опубликовано, гарантированно на диске после flush.
  await storage.flush();

  // Список сессий в папке (включая текущую).
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

  // Один ZIP-архив на все сессии: внутри каждая сессия — отдельный файл.
  final zip = File('${storage.directory}/../team_logger_example_logs.zip');
  await storage.sessions.archiveTo(zip);
  log.i('Logs archived', data: {'path': zip.path, 'size': zip.lengthSync()});

  await storage.close();
}
