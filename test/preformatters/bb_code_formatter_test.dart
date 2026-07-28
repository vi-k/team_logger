import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

const _formatter = BbCodeFormatter();

void main() {
  group('BbCodeFormatter', () {
    test('noColors theme (no styles) leaves the whole text untouched', () {
      const text = 'value=[] items, done [/] IMPORTANT TAIL';

      expect(
        _formatter(LogMainTheme.noColors.info, text),
        text,
      );
    });

    test('known tag is styled and the tail is preserved', () {
      final result = _formatter(
        LogMainTheme.defaultActiveTheme.info,
        'before [b]bold[/b] after',
      );

      expect(result, contains('\x1B['));
      expect(result, contains('bold'));
      expect(result, endsWith(' after'));
    });

    test('style keys with regex special characters are escaped', () {
      final theme = LogMainTheme(
        messageStyles: const {'a.b': LogStyle(ansi.NoStyle())},
      );

      // Настоящий тег обрабатывается (NoStyle снимает разметку)...
      expect(_formatter(theme.info, '[a.b]x[/a.b] tail'), 'x tail');
      // ...а 'aXb' ключом 'a.b' не матчится, текст не искажается.
      const other = '[aXb]y[/aXb] tail2';
      expect(_formatter(theme.info, other), other);
    });

    test('unknown tag with non-empty styles keeps text and tail', () {
      const text = 'x [zzz]q[/zzz] tail';

      expect(
        _formatter(LogMainTheme.defaultActiveTheme.info, text),
        text,
      );
    });
  });
}
