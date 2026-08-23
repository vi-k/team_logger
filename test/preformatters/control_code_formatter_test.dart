import 'dart:convert';

import 'package:team_logger/src/file_storage/file_log_codec.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// The terminal-output trust boundary of review finding #10, now closed.
///
/// The safe mode is on by default: a control sequence in untrusted text is
/// shown rather than sent, so nothing a logged value carries can reach the
/// terminal as a command. These tests replaced the characterization that
/// pinned the old passthrough — it was written to be broken here on purpose.

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

/// What the row carries once the theme's own styling is taken off.
///
/// The theme paints with ANSI codes of its own, so "no ESC in the output"
/// is never the question. The question is whether any ESC came out of the
/// logged text, and this is what leaves only that.
String _payload(String row) => row
    .replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '')
    .replaceAll(RegExp(r' +$'), '');

void main() {
  tearDown(() {
    Loggable.defaultConfig = const LoggableConfig();
    Loggable.forceConfig = const LoggableConfig();
  });

  group('ControlCodeFormatter escaping', () {
    test('default keeps ESC and makes the other C0 codes visible', () {
      // The formatter itself did not change: by the time it runs, the safe
      // mode has already taken the sequences out of the text.
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

  group('safe mode is on by default', () {
    test('a message shows its sequence instead of sending it', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(_clearScreen),
      );

      expect(_payload(row), '[CSI 2 ED]forged');
    });

    test('an ST-terminated OSC 8 hyperlink cannot be forged', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(_oscSt),
      );

      expect(_payload(row), '[OSC 8;;http://evil ST]click[OSC 8;; ST]');
    });

    test('a BEL-terminated OSC is shown whole rather than left open', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('$_esc]8;;http://evil${_bel}click'),
      );

      expect(_payload(row), '[OSC 8;;http://evil BEL]click');
    });

    test('a value inside a plain container is disarmed', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('m', data: {'ua': '$_esc[31mred'}),
      );

      expect(_payload(row), 'm: {₌₁ ua: "[CSI 31 SGR]red"}');
    });

    test('a Loggable property is disarmed', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: Loggable.builder(Object())..prop('ua', '$_esc[31mred'),
        ),
      );

      expect(_payload(row), 'm: Object(ua: "[CSI 31 SGR]red")');
    });

    test('a map key is disarmed', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('m', data: {'$_esc[31mk': 1}),
      );

      expect(_payload(row), 'm: {₌₁ [CSI 31 SGR]k: 1}');
    });

    test('an error text is disarmed', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('m', error: Exception(_clearScreen)),
      );

      expect(row, contains('[CSI 2 ED]forged'));
      expect(row, isNot(contains('$_esc[2J')));
    });

    test('a value handed to a LoggableView is disarmed', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: Loggable.mapBuilder()
            ..prop('v', 0, view: const LoggableView('$_esc[31mred')),
        ),
      );

      expect(_payload(row), 'm: {v: [CSI 31 SGR]red}');
    });

    test('a view keeps the styling the package itself put there', () {
      // A view is a rendering extension: it is handed the theme, and
      // LoggableMultiView and units styling put the theme's own codes into
      // its result. Those are rendered output, not untrusted input, and
      // disarming them would break legitimate views.
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: Loggable.mapBuilder()
            ..prop(
              'v',
              0,
              view: const LoggableMultiView([
                LoggableView(12, units: 'km'),
                LoggableView(7, units: 'NM'),
              ]),
            ),
        ),
      );

      expect(_payload(row), 'm: {v: 12km/7NM}');
      expect(row, isNot(contains('CSI')));
    });

    test('ordinary text is untouched', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i('nothing to see', data: {'a': 'plain'}),
      );

      expect(_payload(row), 'nothing to see: {₌₁ a: "plain"}');
    });
  });

  group('raw ANSI is an explicit opt-out', () {
    test('escapeAnsiCodes: false lets a value keep its own styling', () {
      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: {'ua': '$_esc[31mred'},
          config: const LoggableConfig(escapeAnsiCodes: false),
        ),
      );

      expect(row, contains('$_esc[31mred'));
    });

    test('the application can opt out for everything', () {
      Loggable.defaultConfig = const LoggableConfig(escapeAnsiCodes: false);

      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(_clearScreen),
      );

      expect(row, contains(_clearScreen));
    });

    test('forceConfig cannot be opted out of', () {
      // The point of the force layer: a call site asking for raw ANSI does
      // not get it when the application said otherwise.
      Loggable.forceConfig = const LoggableConfig(escapeAnsiCodes: true);

      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: {'ua': '$_esc[31mred'},
          config: const LoggableConfig(escapeAnsiCodes: false),
        ),
      );

      expect(_payload(row), 'm: {₌₁ ua: "[CSI 31 SGR]red"}');
    });

    test('a container cannot opt out under a forced policy either', () {
      Loggable.forceConfig = const LoggableConfig(escapeAnsiCodes: true);

      final row = _render(
        LogMainTheme.defaultActiveTheme,
        (log) => log.i(
          'm',
          data: Loggable.from(
            {'ua': '$_esc[31mred'},
            config: const LoggableConfig(escapeAnsiCodes: false),
          ),
        ),
      );

      expect(_payload(row), 'm: {₌₁ ua: "[CSI 31 SGR]red"}');
    });
  });

  group('file output', () {
    test('the message is disarmed before it reaches the line', () {
      final codec = FileLogCodec();
      final line = codec.encode(_makeLog((log) => log.i(_clearScreen)));

      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['message'], '[CSI 2 ED]forged');
      expect(line, isNot(contains(_esc)));
    });

    test('a reader printing the decoded message cannot be attacked', () {
      // The file itself was always inert — jsonEncode writes ESC as an
      // escape. What was not safe was decoding the line and printing the
      // message, which handed the terminal a live command.
      final codec = FileLogCodec();
      final line = codec.encode(_makeLog((log) => log.i(_oscSt)));

      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['message'], isNot(contains(_esc)));
    });
  });
}
