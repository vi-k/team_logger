import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

void main() {
  test('team_logger_io exports the file storage API and the core library',
      () async {
    final tmp = await Directory.systemTemp.createTemp('team_logger_test');
    addTearDown(() => tmp.delete(recursive: true));

    final storage = FileLogStorage(
      directory: tmp.path,
      sessionId: 's1',
      dataFormat: FileLogDataFormat.json,
    );
    final log = Logger('app')
      ..level = LogLevels.all
      ..publisher = storage;
    log.i('x');
    await storage.flush().timeout(const Duration(seconds: 5));

    final sessions = await storage.sessions.list();
    expect(sessions.single.id, 's1');
    expect(FileLogCodec.metaKey, ':meta');

    await storage.close();
  });
}
