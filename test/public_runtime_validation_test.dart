import 'dart:io';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

Matcher _argumentError(Object? value, String name) => isA<ArgumentError>()
    .having((error) => error.name, 'name', name)
    .having((error) => error.invalidValue, 'invalidValue', value);

void main() {
  group('ConsoleLogPrinter runtime validation', () {
    final invalidConstructors = <String, ConsoleLogPrinter Function()>{
      'activeMinLevel': () => ConsoleLogPrinter(
            activeMinLevel: LogLevels.info,
            rows: const [],
          ),
      'activeLevels': () => ConsoleLogPrinter(
            activeLevels: const {LogLevels.info},
            rows: const [],
          ),
      'activeNamespaces': () => ConsoleLogPrinter(
            activeNamespaces: const {'app'},
            rows: const [],
          ),
      'activeTraceGroups': () => ConsoleLogPrinter(
            activeTraceGroups: const {'request'},
            rows: const [],
          ),
      'activeTags': () => ConsoleLogPrinter(
            activeTags: const {'important'},
            rows: const [],
          ),
      'isLogActive': () => ConsoleLogPrinter(
            isLogActive: (log) => true,
            rows: const [],
          ),
    };

    for (final MapEntry(key: name, value: construct)
        in invalidConstructors.entries) {
      test('$name requires inactiveTheme', () {
        expect(
          construct,
          throwsA(_argumentError(null, 'inactiveTheme')),
        );
      });
    }
  });

  group('LogMainTheme runtime validation', () {
    const ansi = '\x1B[31m';
    final invalidTokens = <String, LogMainTheme Function()>{
      'openingQuote': () => LogMainTheme(openingQuote: ansi),
      'closingQuote': () => LogMainTheme(closingQuote: ansi),
      'colon': () => LogMainTheme(colon: ansi),
      'ellipsis': () => LogMainTheme(ellipsis: ansi),
      'lineBreak': () => LogMainTheme(lineBreak: ansi),
      'padding': () => LogMainTheme(padding: ansi),
    };

    for (final MapEntry(key: name, value: construct) in invalidTokens.entries) {
      test('$name rejects ANSI escape codes', () {
        expect(construct, throwsA(_argumentError(ansi, name)));
      });
    }

    for (final padding in ['', '  ']) {
      test('padding rejects length ${padding.length}', () {
        expect(
          () => LogMainTheme(padding: padding),
          throwsA(_argumentError(padding, 'padding')),
        );
      });
    }
  });

  group('Loggable iterable renderer runtime validation', () {
    final renderers = <String,
        String Function({
      LoggableConfig config,
      String start,
      String end,
    })>{
      'efficientLengthIterableToString': ({
        config = const LoggableConfig(),
        start = '(',
        end = ')',
      }) =>
          Loggable.efficientLengthIterableToString(
            const [1],
            config: config,
            start: start,
            end: end,
          ),
      'iterableToString': ({
        config = const LoggableConfig(),
        start = '(',
        end = ')',
      }) =>
          Loggable.iterableToString(
            const [1],
            config: config,
            start: start,
            end: end,
          ),
    };

    for (final MapEntry(key: name, value: render) in renderers.entries) {
      test('$name rejects a negative collectionMaxCount', () {
        expect(
          () => render(
            config: const LoggableConfig(collectionMaxCount: -1),
          ),
          throwsA(_argumentError(-1, 'config.collectionMaxCount')),
        );
      });

      test('$name rejects a non-positive collectionMaxStringLength', () {
        for (final value in [0, -1]) {
          expect(
            () => render(
              config: LoggableConfig(collectionMaxStringLength: value),
            ),
            throwsA(
              _argumentError(value, 'config.collectionMaxStringLength'),
            ),
          );
        }
      });

      test('$name rejects control codes in start', () {
        expect(
          () => render(start: '\n'),
          throwsA(_argumentError('\n', 'start')),
        );
      });

      test('$name rejects ANSI escape codes in start', () {
        const ansi = '\x1B[31m';
        expect(
          () => render(start: ansi),
          throwsA(_argumentError(ansi, 'start')),
        );
      });

      test('$name rejects control codes in end', () {
        expect(
          () => render(end: '\n'),
          throwsA(_argumentError('\n', 'end')),
        );
      });
    }
  });

  test('public validation also works with assertions disabled', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        '--packages=${Directory.current.path}/.dart_tool/package_config.json',
        'test/fixtures/public_runtime_validation.dart',
      ],
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  });
}
