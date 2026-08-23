import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  test('team_logger re-exports the minimal ansi style set', () {
    // Compiling is the check itself: Style/NoStyle/Color16/Color256 and the
    // Styles table are reachable without depending on ansi_escape_codes
    // directly.
    const style = Style(foreground: Color256.rgb431);
    const noStyle = NoStyle();
    const color16 = Color16.red;
    const namedStyle = Styles.rgb050;

    expect(style.foreground, isNotNull);
    expect(noStyle, isA<Style>());
    expect(color16, isA<Color16>());
    expect(namedStyle.foreground, isNotNull);
  });

  test('LogBlock is the exported interface README names for row children', () {
    // README teaches `LogRow(children: [...], tail: [...])` as a list of
    // LogBlock; the name has to exist and the built-ins have to implement it.
    const blocks = <LogBlock>[
      LogNum(),
      LogLevelName.short(),
      LogTime.onlyTime(),
      LogPath(),
      LogTraceId(),
      LogMessage(),
      LogTags(),
    ];

    expect(blocks, everyElement(isA<LogBlock>()));
  });

  test('team_logger exports the number formatter typedef', () {
    expect(_plainNumber, isA<LogNumberFormatter>());
    expect(_plainNumber(LogTheme.noColors, 42, 'ignored'), '42');
  });
}

String _plainNumber(LogTheme theme, num value, String pattern) =>
    value.toString();
