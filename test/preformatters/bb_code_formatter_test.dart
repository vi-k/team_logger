import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

const _formatter = BbCodeFormatter();
final _plainTheme = LogMainTheme(
  messageStyles: const {
    'b': LogNoStyle(),
    'success': LogNoStyle(),
  },
).info;

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

    test('a tag added to a mutable style map applies on the next render', () {
      // Review finding #13 claimed a per-theme cache froze the tag set on
      // first use. The scanner that replaced the backtracking regex keeps no
      // cache, so the map is read again on every call and a late tag applies
      // consistently rather than depending on call history.
      final styles = <String, LogStyle>{};
      final theme = LogMainTheme(messageStyles: styles).info;

      expect(_formatter(theme, '[custom]x[/custom]'), '[custom]x[/custom]');

      styles['custom'] = const LogNoStyle();

      expect(_formatter(theme, '[custom]x[/custom]'), 'x');
    });

    test('style keys with regex special characters are escaped', () {
      final theme = LogMainTheme(
        messageStyles: const {'a.b': LogStyle(ansi.NoStyle())},
      );

      // A real tag is handled (NoStyle strips the markup)...
      expect(_formatter(theme.info, '[a.b]x[/a.b] tail'), 'x tail');
      // ...while 'aXb' does not match the 'a.b' key, so the text is intact.
      const other = '[aXb]y[/aXb] tail2';
      expect(_formatter(theme.info, other), other);
    });

    test('style keys containing a closing bracket remain usable', () {
      final theme = LogMainTheme(
        messageStyles: const {'a]b': LogNoStyle()},
      );

      expect(_formatter(theme.info, '[a]b]x[/a]b] tail'), 'x tail');
    });

    test('unknown tag with non-empty styles keeps text and tail', () {
      const text = 'x [zzz]q[/zzz] tail';

      expect(
        _formatter(LogMainTheme.defaultActiveTheme.info, text),
        text,
      );
    });

    test('a stray opening bracket does not hide a following known tag', () {
      expect(_formatter(_plainTheme, '[[b]bold[/b]'), '[bold');
    });

    test('supports properly nested identical tags', () {
      expect(
        _formatter(
          _plainTheme,
          '[b]outer [b]inner[/b] outer[/b]',
        ),
        'outer inner outer',
      );
    });

    test('supports properly nested different tags', () {
      expect(
        _formatter(
          _plainTheme,
          '[b]outer [success]inner[/success] outer[/b]',
        ),
        'outer inner outer',
      );
    });

    test('handles deeply nested tags without recursive parsing', () {
      const depth = 5000;
      final input = '${List.filled(depth, '[b]x').join()}'
          'end${List.filled(depth, '[/b]').join()}';
      final expected = '${List.filled(depth, 'x').join()}end';

      expect(_formatter(_plainTheme, input), expected);
    });

    test('a mismatched closing tag does not pop the open tag', () {
      expect(
        _formatter(
          _plainTheme,
          '[b]one [success]two[/b] three[/success]',
        ),
        '[b]one two[/b] three',
      );
    });

    test(
      'many unclosed known tags do not trigger superlinear backtracking',
      () {
        final text = List.filled(800, '[b]').join();
        final stopwatch = Stopwatch()..start();

        final result = _formatter(_plainTheme, text);
        stopwatch.stop();

        expect(result, text);
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 1)),
          reason: '2,400 malformed characters must not block an isolate',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
