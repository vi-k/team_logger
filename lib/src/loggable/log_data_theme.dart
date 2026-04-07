import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:team_logger/src/log_formatters/extensions.dart';

final class LogDataTheme {
  final ansi.Style title;
  final ansi.Style name;
  final ansi.Style key;
  final ansi.Style index;
  final ansi.Style value;
  final ansi.Style units;
  final ansi.Style dim;
  final ansi.Style level0;
  final ansi.Style level1;
  final ansi.Style level2;
  final ansi.Style level3;
  final ansi.Style levelN;
  final AnsiStyled ellipsis;

  const LogDataTheme({
    required this.title,
    required this.name,
    required this.key,
    required this.index,
    required this.value,
    required this.units,
    required this.dim,
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.levelN,
    required this.ellipsis,
  });

  ansi.Style level(int level) => switch (level) {
        0 => level0,
        1 => level1,
        2 => level2,
        3 => level3,
        _ => levelN,
      };

  static const LogDataTheme noColorsTheme = LogDataTheme(
    title: ansi.Style.defaults,
    name: ansi.Style.defaults,
    key: ansi.Style.defaults,
    index: ansi.Style.defaults,
    value: ansi.Style.defaults,
    units: ansi.Style.defaults,
    dim: ansi.Style.defaults,
    level0: ansi.Style.defaults,
    level1: ansi.Style.defaults,
    level2: ansi.Style.defaults,
    level3: ansi.Style.defaults,
    levelN: ansi.Style.defaults,
    ellipsis: AnsiStyled('…', ansi.Style.defaults),
  );
}
