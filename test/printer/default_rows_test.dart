import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

(Logger, List<String>) _setup({List<LogRow>? rows}) {
  final out = <String>[];
  final log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      rows: rows ?? ConsoleLogPrinter.defaultRows,
      output: out.add,
    );

  return (log, out);
}

void main() {
  group('ConsoleLogPrinter.defaultRows', () {
    test('a printer built with no rows prints', () {
      final out = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          output: out.add,
        );

      log.i('hello');

      expect(out, hasLength(1));
      expect(out.single, contains('hello'));
    });

    test('carries number, level, time, path, message and tags', () {
      final (log, out) = _setup();

      log.i('hello', tags: ['http']);

      // The default layout is the Quick Start one, so every one of its
      // blocks has to show up on the line.
      final line = out.single;
      expect(line, contains('[i]'), reason: line);
      expect(line, contains('[app]'), reason: line);
      expect(line, contains('hello'), reason: line);
      expect(line, contains('#http'), reason: line);
      expect(line, matches(RegExp(r'\(\d+\)')), reason: line);
      expect(line, matches(RegExp(r'\d\d:\d\d:\d\d')), reason: line);
    });

    test('wraps at 120 columns and pads the line out to them', () {
      final (log, out) = _setup();

      log.i('x' * 200);

      expect(out.length, greaterThan(1));
      for (final line in out) {
        expect(line.length, 120, reason: line);
      }
    });

    test('shows a trace id when the log carries one', () {
      final (log, out) = _setup();

      log.i('hello', traceId: TraceId.auto('payment'));

      expect(out.single, contains('payment'));
    });

    test('an explicit rows argument wins over the default', () {
      final (log, out) = _setup(
        rows: const [
          LogRow.singleLine(children: [LogMessage()]),
        ],
      );

      log.i('hello', tags: ['http']);

      expect(out.single, 'hello');
    });

    test('is a shared constant, not rebuilt per printer', () {
      expect(
        identical(ConsoleLogPrinter.defaultRows, ConsoleLogPrinter.defaultRows),
        isTrue,
      );
      expect(ConsoleLogPrinter.defaultRows, hasLength(1));
      expect(ConsoleLogPrinter.defaultRows.single.maxLength, 120);
    });
  });
}
