import 'package:ansi_escape_codes/style.dart' as ansi;

import '../log_formatters/extensions.dart';
import 'loggable.dart';

final class LogDataTheme with Loggable {
  final ansi.Style title;
  final ansi.Style name;
  final ansi.Style key;
  final ansi.Style index;
  final ansi.Style value;
  final ansi.Style units;
  final List<ansi.Style> levels;
  final AnsiStyled ellipsis;

  const LogDataTheme({
    required this.title,
    required this.name,
    required this.key,
    required this.index,
    required this.value,
    required this.units,
    required this.levels,
    required this.ellipsis,
  });

  ansi.Style level(int level) =>
      levels.isEmpty ? const ansi.NoStyle() : levels[level % levels.length];

  static const LogDataTheme noColorsTheme = LogDataTheme(
    title: ansi.NoStyle(),
    name: ansi.NoStyle(),
    key: ansi.NoStyle(),
    index: ansi.NoStyle(),
    value: ansi.NoStyle(),
    units: ansi.NoStyle(),
    levels: [ansi.NoStyle()],
    ellipsis: AnsiStyled('…', ansi.NoStyle()),
  );

  @override
  void collectLoggableData(LoggableData data) {
    final levelsBuf = StringBuffer('"');
    for (final level in levels) {
      levelsBuf.write(level('['));
    }
    for (final level in levels.reversed) {
      levelsBuf.write(level(']'));
    }
    levelsBuf.write('"');

    data
      ..prop('title', title, showName: false, view: title('title'))
      ..prop('name', name, showName: false, view: name('name'))
      ..prop('key', key, showName: false, view: key('key'))
      ..prop('index', index, showName: false, view: index('index'))
      ..prop('value', value, showName: false, view: value('value'))
      ..prop('units', units, showName: false, view: units('units'))
      ..prop('levels', levels, view: levelsBuf.toString())
      ..prop('ellipsis', ellipsis);
  }
}
