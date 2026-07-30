import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

String _mask(String s) => s.replaceAll(RegExp('secret-[0-9]+'), '***');

void main() {
  group('Logger.transformer (e2e)', () {
    (Logger, List<String>) setUpPrinter() {
      final lines = <String>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 120, children: [LogMessage()]),
          ],
          output: lines.add,
        );

      return (logger, lines);
    }

    test('masks the message before the console printer', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = ((log) => log.copyWith(message: _mask(log.message)))
        ..i('token secret-123');

      final output = lines.join('\n');
      expect(output, contains('***'));
      expect(output, isNot(contains('secret-123')));
    });

    test('masks the data before the console printer', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..transformer = ((log) => log.copyWith(data: {'pin': '***'}))
        ..i('payment', data: {'pin': 1234});

      final output = lines.join('\n');
      // Положительное утверждение защищает от слепого теста: если data
      // вообще не печатается с этой конфигурацией rows, тест упадёт —
      // поправить rows, а не убирать проверку.
      expect(output, contains('***'));
      expect(output, isNot(contains('1234')));
    });

    test('drops the log entirely on null', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = ((log) => log.message.contains('secret') ? null : log)
        ..i('token secret-123')
        ..i('plain');

      final output = lines.join('\n');
      expect(output, isNot(contains('secret-123')));
      expect(output, contains('plain'));
    });

    test('fail-closed: a throwing transformer publishes nothing', () {
      final (logger, lines) = setUpPrinter();
      final errors = <Object>[];
      runZonedGuarded(
        () {
          logger
            ..transformer = ((log) => throw StateError('bug'))
            ..i('token secret-123');
        },
        (error, stackTrace) => errors.add(error),
      );

      expect(lines, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('a child logger inherits the transformer', () {
      final (logger, lines) = setUpPrinter();
      logger.transformer = (log) => log.copyWith(message: _mask(log.message));
      final child = logger.createChild(name: 'net');

      child.i('token secret-9');

      expect(lines.join('\n'), isNot(contains('secret-9')));
    });

    test('TransformPublisher masks one destination only', () {
      final console = <Log>[];
      final file = <Log>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = MultiPublisher([
          CustomLogPublisher(console.add),
          TransformPublisher(
            CustomLogPublisher(file.add),
            transformer: (log) => log.copyWith(message: _mask(log.message)),
          ),
        ]);

      logger.i('token secret-123');

      expect(console.single.message, contains('secret-123'));
      expect(file.single.message, isNot(contains('secret-123')));
    });

    test('masked logs reach FileLogStorage as masked JSONL', () async {
      final tmp = await Directory.systemTemp.createTemp('transformer_test');
      addTearDown(() => tmp.delete(recursive: true));

      final storage = FileLogStorage(directory: tmp.path);
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..transformer = ((log) => log.copyWith(message: _mask(log.message)));

      logger.i('token secret-123');
      await storage.flush();
      await storage.close();

      final content = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .map((f) => utf8.decode(f.readAsBytesSync()))
          .join('\n');
      expect(content, contains('***'));
      expect(content, isNot(contains('secret-123')));
    });
  });
}
