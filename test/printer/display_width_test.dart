import 'package:team_logger/src/printer/display_width.dart';
import 'package:test/test.dart';

/// A terminal column is not a UTF-16 code unit. These pin the three classes
/// where they part company — wide East Asian bases, combining sequences and
/// ZWJ emoji — and the cluster arithmetic layout does on top of them.
///
/// Every non-ASCII sample is written as an escape on purpose: an invisible
/// character in the source would make a failure unreadable.

const _cjk = '世'; // 世 — 1 code unit, 2 columns
const _combining = 'e\u0301'; // é — 2 code units, 1 column
const _zwj = '\u200D';
const _family = '\u{1F468}$_zwj\u{1F469}$_zwj\u{1F467}'; // 8 units, 2 columns
const _clef = '\u{1D11E}'; // surrogate pair outside the wide ranges

void main() {
  group('displayWidth', () {
    test('ASCII is one column per code unit', () {
      expect(displayWidth(''), 0);
      expect(displayWidth('abc'), 3);
      expect(displayWidth('a b'), 3);
    });

    test('a wide East Asian base is two columns', () {
      expect(_cjk.length, 1);
      expect(displayWidth(_cjk), 2);
      expect(displayWidth('$_cjk界'), 4);
      expect(displayWidth('a${_cjk}b'), 4);
    });

    test('fullwidth forms are two columns', () {
      expect(displayWidth('Ａ'), 2);
      expect(displayWidth('　'), 2);
    });

    test('a combining sequence is one column', () {
      expect(_combining.length, 2);
      expect(displayWidth(_combining), 1);
      expect(displayWidth('caf$_combining'), 4);
    });

    test('a ZWJ emoji sequence is one cluster of two columns', () {
      expect(_family.length, 8);
      expect(displayWidth(_family), 2);
    });

    test('a surrogate pair outside the wide ranges is one column', () {
      expect(_clef.length, 2);
      expect(displayWidth(_clef), 1);
    });

    test('a stray combining mark on its own draws nothing', () {
      expect(displayWidth('\u0301'), 0);
      expect(displayWidth('\u200B'), 0);
    });
  });

  group('ClusterIndex', () {
    test('reports the width of the whole text', () {
      expect(ClusterIndex('abc').width, 3);
      expect(ClusterIndex('$_cjk界').width, 4);
      expect(ClusterIndex(_family).width, 2);
    });

    test('columnsFrom measures the tail, not the code units left', () {
      final index = ClusterIndex('a${_cjk}b');

      expect(index.columnsFrom(0), 4);
      expect(index.columnsFrom(1), 3);
      expect(index.columnsFrom(2), 1);
      expect(index.columnsFrom(3), 0);
    });

    test('a budget takes whole clusters only', () {
      final index = ClusterIndex('$_cjk界');

      // One column cannot hold a two-column glyph.
      expect(index.codeUnitsForColumns(0, 1), 0);
      expect(index.codeUnitsForColumns(0, 2), 1);
      expect(index.codeUnitsForColumns(0, 3), 1);
      expect(index.codeUnitsForColumns(0, 4), 2);
    });

    test('a combining sequence is taken whole or not at all', () {
      final index = ClusterIndex(_combining);

      expect(index.codeUnitsForColumns(0, 0), 0);
      expect(index.codeUnitsForColumns(0, 1), 2);
    });

    test('a ZWJ sequence is never cut in the middle', () {
      final index = ClusterIndex('a$_family');

      expect(index.codeUnitsForColumns(0, 1), 1);
      expect(index.codeUnitsForColumns(0, 2), 1);
      expect(index.codeUnitsForColumns(0, 3), 9);
    });

    test('ASCII takes the fast path and still answers the same', () {
      final index = ClusterIndex('hello');

      expect(index.width, 5);
      expect(index.columnsFrom(2), 3);
      expect(index.codeUnitsForColumns(0, 3), 3);
      expect(index.codeUnitsForColumns(2, 99), 3);
    });

    test('a cluster wider than the budget still makes progress', () {
      final index = ClusterIndex('$_cjk界');

      // Nothing fits, but a wrap loop must not stall: the glyph goes out
      // whole and overflows by a column rather than being halved.
      expect(index.codeUnitsForColumnsAtLeastOne(0, 1), 1);
      expect(index.codeUnitsForColumnsAtLeastOne(1, 1), 1);
      expect(index.codeUnitsForColumnsAtLeastOne(2, 1), 0);
    });

    test('walking a mixed line by budget covers it exactly once', () {
      const text = 'a${_cjk}b\u{1F468}$_zwj\u{1F469}c';
      final index = ClusterIndex(text);
      final taken = <String>[];

      var start = 0;
      while (start < index.codeUnits) {
        final take = index.codeUnitsForColumnsAtLeastOne(start, 3);
        taken.add(text.substring(start, start + take));
        start += take;
      }

      expect(taken.join(), text);
      expect(taken.every((s) => displayWidth(s) <= 3), isTrue);
    });
  });
}
