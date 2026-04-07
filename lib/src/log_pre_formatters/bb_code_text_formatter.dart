import '../logger/log.dart';
import '../publishers/log_style.dart';
import '../publishers/log_theme.dart';
import 'log_pre_formatter.dart';

final class BbCodeLogPreFormatter implements LogPreFormatter {
  final Map<String, BbCodeFormat> formatters;
  final RegExp _re;

  BbCodeLogPreFormatter({required this.formatters})
      : _re = RegExp(
          r'(?<prefix>(?:\[\[|\]\]|.)*?)\[(?<tag>'
          '${formatters.keys.toSet().join('|')}'
          r')\](?<content>(?:\[\[|\]\]|.)*?)\[\/\k<tag>\]',
          dotAll: true,
        );

  @override
  String call(Log log, LogTheme theme, String text) {
    final buf = StringBuffer();
    var last = 0;

    final matches = _re.allMatches(text);

    for (final m in matches) {
      final tag = m.namedGroup('tag')!;
      final fmt = formatters[tag];
      if (fmt == null) {
        return m[0]!;
      }

      final prefix = m.namedGroup('prefix')!;
      final content = call(log, theme, m.namedGroup('content')!);
      final result = fmt(log, tag, content);

      buf
        ..write(prefix)
        ..write(result);

      last = m.end;
    }

    if (text.length > last) {
      buf.write(text.substring(last));
    }

    return buf.toString().replaceAll('[[', '[').replaceAll(']]', ']');
  }
}

abstract interface class BbCodeFormat {
  const factory BbCodeFormat.colorize(LogStyle style) = _BbCodeColorize;

  const factory BbCodeFormat.noColor() = _BbCodeNoColor;

  const factory BbCodeFormat.asIs() = _BbCodeAsIs;

  const factory BbCodeFormat.replace(
    String Function(Log log, String code, String text) replacer,
  ) = _BbCodeReplace;

  String call(Log log, String code, String text);
}

final class _BbCodeColorize implements BbCodeFormat {
  final LogStyle style;

  const _BbCodeColorize(this.style);

  @override
  String call(Log log, String code, String text) => style[log.level](text);
}

final class _BbCodeAsIs implements BbCodeFormat {
  const _BbCodeAsIs();

  @override
  String call(Log log, String code, String text) => '[$code]$text[/$code]';
}

final class _BbCodeNoColor implements BbCodeFormat {
  const _BbCodeNoColor();

  @override
  String call(Log log, String code, String text) => text;
}

final class _BbCodeReplace implements BbCodeFormat {
  final String Function(Log log, String code, String text) replacer;

  const _BbCodeReplace(this.replacer);

  @override
  String call(Log log, String code, String text) => replacer(log, code, text);
}
