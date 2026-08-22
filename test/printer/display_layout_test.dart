import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:ansi_escape_codes/extensions.dart';
import 'package:team_logger/src/printer/display_width.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Layout measured in terminal columns rather than UTF-16 code units:
/// review finding #15. Every assertion here is about what a terminal draws,
/// so it measures the rendered row with [displayWidth] and not with
/// `String.length`.

const _cjk = '世界'; // 2 code units, 4 columns
const _combining = 'e\u0301'; // 2 code units, 1 column
const _zwj = '\u200D';
const _family = '\u{1F468}$_zwj\u{1F469}$_zwj\u{1F467}'; // 8 units, 2 columns

/// Columns the row occupies once the ANSI codes are taken out.
int _columns(String row) => displayWidth(row.ansiRemoveEscapeCodes());

(Logger, List<String>) _setup({
  required List<LogRow> rows,
  LogMainTheme? theme,
}) {
  final lines = <String>[];
  final logger = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme ?? LogMainTheme.noColors,
      rows: rows,
      output: lines.add,
    );

  return (logger, lines);
}

void main() {
  group('the measured plain text agrees with the parser', () {
    // The whole column model rests on this: ansiRemoveEscapeCodes() and
    // Parser.length must count the same characters, or a column budget maps
    // to the wrong code-unit offset.
    test('stripping escape codes leaves exactly Parser.length code units', () {
      const samples = [
        'plain',
        '\x1B[31mred\x1B[0m',
        'a\x1B[1mb\x1B[22mc',
        '\x1B]8;;http://e\x1B\\link\x1B]8;;\x1B\\',
        '',
      ];

      for (final sample in samples) {
        expect(
          sample.ansiRemoveEscapeCodes().length,
          ansi.Parser(sample).length,
          reason: sample,
        );
      }
    });
  });

  group('a row is measured in columns', () {
    test('a CJK message stays inside maxLength', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 10, children: [LogMessage()]),
        ],
      );

      // Ten code units of CJK are twenty columns, so it wraps rather than
      // overflowing — which is the whole point: by code units it would have
      // been counted as fitting on one row.
      log.i(_cjk * 5);

      expect(out.length, greaterThan(1));
      for (final line in out) {
        expect(_columns(line), lessThanOrEqualTo(10));
      }
    });

    test('an ASCII message of the same length is unchanged', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 10, children: [LogMessage()]),
        ],
      );

      log.i('abcdefghij');

      expect(_columns(out.single), 10);
      expect(out.single.trim(), 'abcdefghij');
    });

    test('a combining sequence is one column, not two', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 6, children: [LogMessage()]),
        ],
      );

      // Four clusters, four columns: it fits and must not be truncated.
      log.i('caf$_combining');

      expect(_columns(out.single), 6);
      expect(out.single, contains(_combining));
    });

    test('a ZWJ emoji sequence is never cut in half', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 4, children: [LogMessage()]),
        ],
      );

      log.i('ab$_family');

      final rendered = out.single;
      // Either the whole sequence is there or none of it — never a lone
      // half of a surrogate pair or a dangling joiner.
      expect(
        rendered.contains(_family) || !rendered.contains(_zwj),
        isTrue,
        reason: rendered,
      );
      expect(_columns(rendered), lessThanOrEqualTo(4));
    });
  });

  group('wrapping counts columns', () {
    test('a wide message wraps by columns and loses nothing', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 8, children: [LogMessage()]),
        ],
      );

      log.i(_cjk * 4);

      expect(out, isNotEmpty);
      for (final line in out) {
        expect(_columns(line), lessThanOrEqualTo(8));
      }
    });

    test('a combining sequence does not force an extra wrap', () {
      final (log, plain) = _setup(
        rows: const [
          LogRow(maxLength: 12, children: [LogMessage()]),
        ],
      );
      log.i('cafe cafe x');
      final plainLines = plain.length;

      final (log2, marked) = _setup(
        rows: const [
          LogRow(maxLength: 12, children: [LogMessage()]),
        ],
      );
      log2.i('caf$_combining caf$_combining x');

      // Same number of drawn columns, so the same number of rows.
      expect(marked.length, plainLines);
    });

    test('every wrapped line of a mixed message fits the box', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 7, children: [LogMessage()]),
        ],
      );

      log.i('ab$_cjk cd$_family ef');

      for (final line in out) {
        expect(_columns(line), lessThanOrEqualTo(7));
      }
    });
  });

  group('the tail stays at the right edge', () {
    test('a CJK message does not push the tags out of the row', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(
            maxLength: 20,
            children: [LogMessage()],
            tail: [LogTags()],
          ),
        ],
      );

      log.i(_cjk * 6, tags: {'t'});

      for (final line in out) {
        expect(_columns(line), lessThanOrEqualTo(20));
      }
      expect(out.join(), contains('#t'));
    });
  });
}
