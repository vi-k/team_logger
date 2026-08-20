import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  test('team_logger re-exports the minimal ansi style set', () {
    // Компилируемость и есть проверка: Style/NoStyle/Color16/Color256
    // и таблица Styles доступны без прямой зависимости от
    // ansi_escape_codes.
    const style = Style(foreground: Color256.rgb431);
    const noStyle = NoStyle();
    const color16 = Color16.red;
    const namedStyle = Styles.rgb050;

    expect(style.foreground, isNotNull);
    expect(noStyle, isA<Style>());
    expect(color16, isA<Color16>());
    expect(namedStyle.foreground, isNotNull);
  });

  test('team_logger exports the number formatter typedef', () {
    expect(_plainNumber, isA<LogNumberFormatter>());
    expect(_plainNumber(LogTheme.noColors, 42, 'ignored'), '42');
  });
}

String _plainNumber(LogTheme theme, num value, String pattern) =>
    value.toString();
