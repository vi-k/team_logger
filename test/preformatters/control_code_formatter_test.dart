import 'dart:convert';

import 'package:team_logger/src/file_storage/file_log_codec.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// The terminal-output trust boundary of review finding #10, pinned as a
/// characterization: the default theme lets ESC through, every other C0 is
/// made visible, and the strict mode covers the message and plain
/// containers but not `Loggable` properties. Behavior here is accepted, not
/// fixed — a future safe mode must break these tests on purpose.

const _esc = '\x1B';
const _bel = '\x07';

/// A clear-screen sequence: the cheapest way to show ESC reaching output.
const _clearScreen = '$_esc[2Jforged';

/// OSC 8 terminated by ST (`ESC \`) — a forged clickable hyperlink.
const _oscSt = '$_esc]8;;http://evil$_esc\\click$_esc]8;;$_esc\\';

final class _CapturePublisher implements CustomLogPublisher<Log> {
  final logs = <Log>[];

  @override
  void publish(Log log) => logs.add(log);
}

Log _makeLog(void Function(Logger log) emit) {
  final publisher = _CapturePublisher();
  final logger = Logger('t')
    ..level = LogLevels.all
    ..publisher = publisher;

  emit(logger);

  return publisher.logs.single;
}

/// Renders one log through a console printer and returns the single row.
String _render(LogMainTheme theme, void Function(Logger log) emit) {
  final captured = <String>[];
  final logger = Logger('t')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme,
      rows: const [
        LogRow(maxLength: 200, children: [LogMessage()]),
      ],
      output: captured.add,
    );

  emit(logger);

  return captured.single;
}

/// The default theme with ESC escaping switched on.
LogMainTheme _strictTheme() => LogMainTheme.defaultActiveTheme.copyWith(
      valueFormatter: const ControlCodeFormatter(excludeEscCode: false),
    );

void main() {
  group('ControlCodeFormatter escaping', () {
    test('default keeps ESC and makes the other C0 codes visible', () {
      const formatter = ControlCodeFormatter();

      expect(formatter(LogTheme.noColors, _clearScreen), _clearScreen);
      expect(formatter(LogTheme.noColors, 'a${_bel}b'), r'a\x07b');
      expect(formatter(LogTheme.noColors, 'a\rb'), r'a\rb');
    });

    test('excludeEscCode: false escapes ESC as well', () {
      const formatter = ControlCodeFormatter(excludeEscCode: false);

      final result = formatter(LogTheme.noColors, _clearScreen);

      expect(result, isNot(contains(_esc)));
      expect(result, r'\x1B[2Jforged');
    });
  });

  group('default theme passes control sequences to the terminal', () {
    test('a message keeps its own ESC sequence', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(_clearScreen),
      );

      expect(row, contains(_clearScreen));
    });

    test('an ST-terminated OSC 8 hyperlink survives whole', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(_oscSt),
      );

      expect(row, contains(_oscSt));
    });

    test('a BEL-terminated OSC is left unterminated instead', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('$_esc]8;;http://evil${_bel}click'),
      );

      expect(row, contains('$_esc]8;;http://evil'));
      expect(row, contains(r'\x07'));
    });

    test('a value inside a plain container keeps its ESC sequence', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('m', data: {'ua': '$_esc[31mred'}),
      );

      expect(row, contains('$_esc[31mred'));
    });

    test('a Loggable property keeps its ESC sequence', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: Loggable.builder(Object())..prop('ua', '$_esc[31mred'),
        ),
      );

      expect(row, contains('$_esc[31mred'));
    });
  });

  group('strict theme', () {
    test('escapes ESC in the message', () {
      final row = _render(_strictTheme(), (log) => log.i(_clearScreen));

      expect(row, contains(r'\x1B'));
      expect(row, isNot(contains('$_esc[2J')));
    });

    test('escapes ESC in a plain container value', () {
      final row = _render(
        _strictTheme(),
        (log) => log.i('m', data: {'ua': '$_esc[31mred'}),
      );

      expect(row, contains(r'\x1B'));
      expect(row, isNot(contains('$_esc[31m')));
    });

    test('does not escape the theme own codes in a Loggable property', () {
      final row = _render(
        _strictTheme(),
        (log) => log.i(
          'm',
          data: Loggable.builder(Object())..prop('ok', 'plain'),
        ),
      );

      // Nothing was injected here, so nothing may be escaped. The value
      // formatter used to run a second time over text the theme had already
      // styled, which turned its own reset into visible litter.
      expect(row, isNot(contains(r'\x1B')));
      expect(row, contains('plain'));
    });

    test('still escapes an injected sequence inside a Loggable property', () {
      final row = _render(
        _strictTheme(),
        (log) => log.i(
          'm',
          data: Loggable.builder(Object())..prop('ua', '$_esc[31mred'),
        ),
      );

      expect(row, contains(r'\x1B'));
      expect(row, isNot(contains('$_esc[31m')));
    });
  });

  group('file output', () {
    test('ESC reaches the JSONL line only as a JSON escape', () {
      final codec = FileLogCodec();
      final line = codec.encode(_makeLog((log) => log.i(_clearScreen)));

      // The file on disk is inert: `cat` and `tail` show the escape text.
      expect(line, isNot(contains(_esc)));
      expect(line, contains(r'\u001b'));

      // It becomes a live sequence again once a reader decodes the JSON.
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['message'], contains(_esc));
    });
  });
}
