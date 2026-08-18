import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Пины на форматирование чисел через `package:format`.
///
/// `intFormat`/`doubleFormat` уходят в `format('{:$f}', value)`, а
/// ограничение на пакет намеренно широкое — какая ветка `format` попадёт к
/// пользователю, решает его SDK (Flutter пиннит `characters` и `intl`, и
/// разные линии тянут разные версии). Эти тесты держат вывод одинаковым во
/// всех допустимых ветках: они прогонялись на 1.5.2, 1.6.0, 3.0.0 и 4.0.0.
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

    cases.forEach((spec, expected) {
      test('{:$spec} renders $expected', () {
        expect(render(42, LoggableConfig(intFormat: spec)), expected);
      });
    });

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
      // 3.x/4.x печатают здесь '1234.5678' — см. шапку файла.
      'g': '1234.57',
    };

    cases.forEach((spec, expected) {
      test('{:$spec} renders $expected', () {
        expect(
          render(1234.5678, LoggableConfig(doubleFormat: spec)),
          expected,
        );
      });
    });

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
