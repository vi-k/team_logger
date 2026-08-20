import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('LogMainTheme.numberFormatter', () {
    test('default ignores the pattern and prints toString()', () {
      final theme = LogMainTheme.noColors.verbose;

      expect(theme.formatNumber(1234567, '{:,d}'), '1234567');
      expect(theme.formatNumber(1234.5678, '{:.2f}'), '1234.5678');
    });

    test('formatNumber hands over the value and the pattern verbatim', () {
      final calls = <(num, String)>[];
      final theme = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) {
          calls.add((value, pattern));

          return 'formatted';
        },
      ).verbose;

      expect(theme.formatNumber(42, 'not a format'), 'formatted');
      expect(calls, [(42, 'not a format')]);
    });

    test('the formatter receives the level theme it was taken from', () {
      late LogTheme seen;
      final main = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) {
          seen = theme;

          return '';
        },
      );

      main.error.formatNumber(1, 'p');

      expect(seen.level, LogLevels.error);
    });

    test('copyWith carries the formatter through a later copy', () {
      final theme = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) => 'x',
      );

      expect(theme.copyWith(colon: '=').verbose.formatNumber(1, 'p'), 'x');
    });
  });
}
