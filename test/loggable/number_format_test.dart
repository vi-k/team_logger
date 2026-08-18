import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Пины на форматирование чисел через `package:format`.
///
/// `intFormat`/`doubleFormat` уходят в `format('{:$f}', value)`, то есть
/// вывод чисел задаёт сторонний пакет, а покрытия у этого не было вовсе.
/// Пробел вскрылся при переборе версий `format`: между ветками 1.x и 4.x
/// расходится `{:g}` — для 1234.5678 ветка 1.x печатала `1234.57`, ветка
/// 4.x печатает `1234.5678`. Тесты держат такую границу видимой при
/// следующем обновлении.
void main() {
  String render(Object? value, LoggableConfig config) =>
      Loggable.objectToString(value, config: config);

  group('intFormat', () {
    const cases = <String, String>{
      'd': '42',
      '5d': '   42',
      '-5d': '   42',
      '05d': '00042',
      ',d': '42',
      'x': '2a',
      'X': '2A',
      'o': '52',
      'b': '101010',
      '+d': '+42',
    };

    for (final MapEntry(key: spec, value: expected) in cases.entries) {
      test('{:$spec} renders $expected', () {
        expect(render(42, LoggableConfig(intFormat: spec)), expected);
      });
    }

    test('groups thousands', () {
      expect(
        render(1234567, const LoggableConfig(intFormat: ',d')),
        '1,234,567',
      );
    });

    test('keeps units after the formatted value', () {
      expect(
        render(42, const LoggableConfig(intFormat: '05d', units: 'ms')),
        '00042ms',
      );
    });
  });

  group('doubleFormat', () {
    const cases = <String, String>{
      '.2f': '1234.57',
      '.0f': '1235',
      '10.2f': '   1234.57',
      '-10.2f': '   1234.57',
      '010.2f': '0001234.57',
      ',.2f': '1,234.57',
      '+.2f': '+1234.57',
      '.3e': '1.235e+3',
      // На ветке 1.x здесь было '1234.57' — см. шапку файла.
      'g': '1234.5678',
    };

    for (final MapEntry(key: spec, value: expected) in cases.entries) {
      test('{:$spec} renders $expected', () {
        expect(
          render(1234.5678, LoggableConfig(doubleFormat: spec)),
          expected,
        );
      });
    }

    test('rounds half to even the same way in every branch', () {
      expect(render(2.675, const LoggableConfig(doubleFormat: '.2f')), '2.67');
      expect(render(2.665, const LoggableConfig(doubleFormat: '.2f')), '2.67');
    });

    test('keeps units after the formatted value', () {
      expect(
        render(
          1234.5678,
          const LoggableConfig(doubleFormat: '.1f', units: 'm'),
        ),
        '1234.6m',
      );
    });
  });
}
