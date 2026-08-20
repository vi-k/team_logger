import 'package:format/format.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Пины на форматирование чисел через форматтер темы.
///
/// `intFormat`/`doubleFormat` — непрозрачные шаблоны: пакет передаёт их в
/// `LogMainTheme.numberFormatter` вместе со значением и сам не разбирает.
/// Здесь в тему кладётся рецепт поверх `package:format` — тот самый, что
/// документирует README, — поэтому файл продолжает пинить и поведение
/// `format`. Пробел вскрылся при переборе его версий: между ветками 1.x и
/// 4.x расходится `{:g}` — для 1234.5678 ветка 1.x печатала `1234.57`,
/// ветка 4.x печатает `1234.5678`.
void main() {
  final formatting = LogMainTheme.noColors
      .copyWith(
        numberFormatter: (theme, value, pattern) => format(pattern, value),
      )
      .verbose;

  String render(Object? value, LoggableConfig config) =>
      Loggable.objectToString(value, theme: formatting, config: config);

  String plain(Object? value, LoggableConfig config) =>
      Loggable.objectToString(value, config: config);

  group('intFormat', () {
    const cases = <String, String>{
      '{:d}': '42',
      '{:5d}': '   42',
      '{:-5d}': '   42',
      '{:05d}': '00042',
      '{:,d}': '42',
      '{:x}': '2a',
      '{:X}': '2A',
      '{:o}': '52',
      '{:b}': '101010',
      '{:+d}': '+42',
    };

    for (final MapEntry(key: pattern, value: expected) in cases.entries) {
      test('$pattern renders $expected', () {
        expect(render(42, LoggableConfig(intFormat: pattern)), expected);
      });
    }

    test('groups thousands', () {
      expect(
        render(1234567, const LoggableConfig(intFormat: '{:,d}')),
        '1,234,567',
      );
    });

    test('keeps units after the formatted value', () {
      expect(
        render(42, const LoggableConfig(intFormat: '{:05d}', units: 'ms')),
        '00042ms',
      );
    });

    // Локалезависимого варианта здесь нет: `format` читает свою
    // `NumberLocale` из инстанса `Format`, а рецепт зовёт топ-уровневый
    // `format()`. С версии 3.0.0 он не смотрит и в `Intl.defaultLocale`.
    test('n follows the C locale and does not group', () {
      expect(
        render(1234567, const LoggableConfig(intFormat: '{:n}')),
        '1234567',
      );
    });

    test(',n is rejected by the installed formatter', () {
      expect(
        () => render(1234567, const LoggableConfig(intFormat: '{:,n}')),
        throwsA(anything),
      );
    });
  });

  group('doubleFormat', () {
    const cases = <String, String>{
      '{:.2f}': '1234.57',
      '{:.0f}': '1235',
      '{:10.2f}': '   1234.57',
      '{:-10.2f}': '   1234.57',
      '{:010.2f}': '0001234.57',
      '{:,.2f}': '1,234.57',
      '{:+.2f}': '+1234.57',
      '{:.3e}': '1.235e+3',
      // На ветке 1.x здесь было '1234.57' — см. шапку файла.
      '{:g}': '1234.5678',
    };

    for (final MapEntry(key: pattern, value: expected) in cases.entries) {
      test('$pattern renders $expected', () {
        expect(
          render(1234.5678, LoggableConfig(doubleFormat: pattern)),
          expected,
        );
      });
    }

    test('rounds half to even the same way in every branch', () {
      expect(
        render(2.675, const LoggableConfig(doubleFormat: '{:.2f}')),
        '2.67',
      );
      expect(
        render(2.665, const LoggableConfig(doubleFormat: '{:.2f}')),
        '2.67',
      );
    });

    test('keeps units after the formatted value', () {
      expect(
        render(
          1234.5678,
          const LoggableConfig(doubleFormat: '{:.1f}', units: 'm'),
        ),
        '1234.6m',
      );
    });
  });

  group('the pattern is opaque to the package', () {
    test('it reaches the formatter exactly as written', () {
      final seen = <(num, String)>[];
      final theme = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) {
          seen.add((value, pattern));

          return 'formatted';
        },
      ).verbose;

      expect(
        Loggable.objectToString(
          42,
          theme: theme,
          config: const LoggableConfig(intFormat: 'not a format at all'),
        ),
        'formatted',
      );
      expect(seen, [(42, 'not a format at all')]);
    });

    test('nan and inf never reach the formatter', () {
      final seen = <String>[];
      final theme = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) {
          seen.add(pattern);

          return 'formatted';
        },
      ).verbose;

      String rendered(double value) => Loggable.objectToString(
            value,
            theme: theme,
            config: const LoggableConfig(doubleFormat: '{:.2f}'),
          );

      expect(rendered(double.nan), 'nan');
      expect(rendered(double.infinity), 'inf');
      expect(rendered(double.negativeInfinity), '-inf');
      expect(seen, isEmpty);
    });
  });

  group('no formatter in the theme', () {
    test('an int pattern is ignored, not applied', () {
      expect(
        plain(1234567, const LoggableConfig(intFormat: '{:,d}')),
        '1234567',
      );
    });

    test('a double pattern is ignored, not applied', () {
      expect(
        plain(1234.5678, const LoggableConfig(doubleFormat: '{:.2f}')),
        '1234.5678',
      );
    });

    test('units still follow the value', () {
      expect(
        plain(42, const LoggableConfig(intFormat: '{:05d}', units: 'ms')),
        '42ms',
      );
    });

    test('a pattern nobody can honour does not throw', () {
      expect(
        () => plain(1234567, const LoggableConfig(intFormat: '{:,n}')),
        returnsNormally,
      );
    });
  });
}
