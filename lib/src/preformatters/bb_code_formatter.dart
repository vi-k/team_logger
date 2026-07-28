import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

/// Compiles inline BBCode (`[b]...[/b]`, `[success]...[/success]`) into
/// ANSI escape codes using the theme's message styles.
///
/// Unknown tags are left as-is. Nested *identical* tags are not supported
/// (`[b]a [b]x[/b] c[/b]` matches the first closing tag).
final class BbCodeFormatter with Loggable implements LogPreFormatter {
  static final _reExpando = Expando<RegExp>();

  const BbCodeFormatter();

  @override
  String call(LogTheme theme, String text) {
    final tags = {
      ...theme.data.messageStyles.keys,
      ...theme.main.messageStyles.keys,
    };
    // Без стилей нет и тегов: пустая альтернатива в регулярке матчила бы
    // `[]…[/]` и искажала текст.
    if (tags.isEmpty) return text;

    final buf = StringBuffer();
    var last = 0;

    final re = _reExpando[theme] ??= RegExp(
      r'(?<prefix>(?:.)*?)\[(?<tag>'
      '${tags.map(RegExp.escape).join('|')}'
      r')\](?<content>(?:.)*?)\[\/\k<tag>\]',
      dotAll: true,
    );
    final matches = re.allMatches(text);

    for (final m in matches) {
      final tag = m.namedGroup('tag')!;
      final style = theme.messageStyle(tag);
      if (style == null) {
        // Тег без стиля оставляем как есть, не теряя остаток текста.
        buf.write(m[0]);
        last = m.end;
        continue;
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
