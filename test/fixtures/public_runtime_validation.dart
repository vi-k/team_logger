// ignore_for_file: avoid_catches_without_on_clauses, avoid_catching_errors

import 'dart:async';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';

Future<void> main() async {
  var assertionsEnabled = false;
  assert(assertionsEnabled = true);
  if (assertionsEnabled) {
    stderr.writeln('The validation probe must run with assertions disabled.');
    exitCode = 64;
    return;
  }

  final failures = <String>[];
  final temporaryDirectory =
      await Directory.systemTemp.createTemp('team_logger_validation');

  Future<void> expectArgumentError(
    String label,
    String expectedName,
    Object? expectedValue,
    FutureOr<Object?> Function() invoke,
  ) async {
    Object? returned;
    try {
      returned = await invoke();
      failures.add('$label returned normally');
    } on ArgumentError catch (error) {
      if (error.name != expectedName || error.invalidValue != expectedValue) {
        failures.add(
          '$label threw ArgumentError with '
          'name=${error.name}, invalidValue=${error.invalidValue}',
        );
      }
      return;
    } catch (error) {
      failures.add('$label threw ${error.runtimeType}: $error');
      return;
    }

    if (returned case final FileLogStorage storage) {
      try {
        await storage.close();
      } catch (_) {
        // The old implementation may fail asynchronously after accepting an
        // invalid constructor argument. The missing ArgumentError above is
        // the contract failure this probe reports.
      }
    } else if (returned case final LogStorage storage) {
      await storage.dispose();
    }
  }

  try {
    await expectArgumentError(
      'LogStorage.maxCount',
      'maxCount',
      0,
      () => LogStorage(maxCount: 0),
    );
    await expectArgumentError(
      'FileLogStorage.maxChunkSize',
      'maxChunkSize',
      -1,
      () => FileLogStorage(
        directory: temporaryDirectory.path,
        maxChunkSize: -1,
      ),
    );
    await expectArgumentError(
      'FileLogStorage.maxSessionSize',
      'maxSessionSize',
      1000,
      () => FileLogStorage(
        directory: temporaryDirectory.path,
        maxSessionSize: 1000,
        maxChunkSize: 600,
      ),
    );
    await expectArgumentError(
      'FileLogStorage.maxTotalSize',
      'maxTotalSize',
      500,
      () => FileLogStorage(
        directory: temporaryDirectory.path,
        maxSessionSize: 1000,
        maxChunkSize: 500,
        maxTotalSize: 500,
      ),
    );
    await expectArgumentError(
      'FileLogStorage.maxQueueSize',
      'maxQueueSize',
      -1,
      () => FileLogStorage(
        directory: temporaryDirectory.path,
        maxQueueSize: -1,
      ),
    );
    await expectArgumentError(
      'ConsoleLogPrinter.inactiveTheme',
      'inactiveTheme',
      null,
      () => ConsoleLogPrinter(
        activeTags: const {'important'},
        rows: const [],
      ),
    );
    await expectArgumentError(
      'LogMainTheme.padding',
      'padding',
      '',
      () => LogMainTheme(padding: ''),
    );
    await expectArgumentError(
      'Loggable.efficientLengthIterableToString',
      'config.collectionMaxCount',
      -1,
      () => Loggable.efficientLengthIterableToString(
        const [1],
        config: const LoggableConfig(collectionMaxCount: -1),
      ),
    );
    await expectArgumentError(
      'Loggable.iterableToString',
      'config.collectionMaxCount',
      -1,
      () => Loggable.iterableToString(
        const [1],
        config: const LoggableConfig(collectionMaxCount: -1),
      ),
    );
  } finally {
    await temporaryDirectory.delete(recursive: true);
  }

  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
  }
}
