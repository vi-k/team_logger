import '../loggable/loggable.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class BbCodeFormatter with Loggable implements LogPreFormatter {
  static final _reExpando = Expando<RegExp>();

  const BbCodeFormatter();

  @override
  String call(LogLevelTheme theme, String text) {
    final buf = StringBuffer();
    var last = 0;

    final re = _reExpando[theme] ??= RegExp(
      r'(?<prefix>(?:.)*?)\[(?<tag>'
      '${theme.messageStyles.keys.join('|')}'
      r')\](?<content>(?:.)*?)\[\/\k<tag>\]',
      dotAll: true,
    );
    final matches = re.allMatches(text);

    for (final m in matches) {
      final tag = m.namedGroup('tag')!;
      final style = theme.messageStyles[tag];
      if (style == null) {
        return m[0]!;
      }

      final prefix = m.namedGroup('prefix')!;
      final content = call(theme, m.namedGroup('content')!);
      final result = style(content);

      buf
        ..write(prefix)
        ..write(result);

      last = m.end;
    }

    if (text.length > last) {
      buf.write(text.substring(last));
    }

    return buf.toString();
  }

  @override
  void collectLoggableData(LoggableData data) {}
}
