part of 'log_main_theme.dart';

final class LogTheme with Loggable {
  final LogMainTheme main;
  final int level;
  final LogThemeData data;

  LogTheme._(this.main, this.level) : data = main._dataByLevel(level);

  const LogTheme._raw(this.main, this.level, this.data);

  static const LogTheme noColors = LogTheme._raw(
    LogMainTheme.noColors,
    LogLevels.verbose,
    LogThemeData.noColors,
  );

  String get styledOpeningQuote => data.quotesStyle(main.openingQuote);

  String get styledClosingQuote => data.quotesStyle(main.closingQuote);

  String get styledColon => data.colonStyle(main.colon);

  String get styledEllipsis => data.ellipsisStyle(main.ellipsis);

  String get styledLineBreak => data.lineBreakStyle(main.lineBreak);

  String styledPadding(int count) => data.paddingStyle(main.padding * count);

  ansi.Style? messageStyle(String tag) => switch (data.messageStyles[tag]) {
        _LogStyle(:final style) => style,
        LogLazyStyle(:final call) => call(this),
        null => switch (main.messageStyles[tag]) {
            _LogStyle(:final style) => style,
            LogLazyStyle(:final call) => call(this),
            null => null,
          },
      };

  String formatValue(String value) => main.valueFormatter(this, value);

  String formatMessage(String value) => main.messageFormatter(this, value);

  String formatIndex(int index) => main.indexFormatter(this, index);

  String formatCount(int count) => main.countFormatter(this, count);

  // Пустой depthThemes деградирует в бесстилевой вариант, а не роняет
  // форматирование первого же объекта.
  LogDepthTheme depthTheme(int depth) => data.depthThemes.isNotEmpty
      ? data.depthThemes[depth % data.depthThemes.length]
      : const LogDepthTheme.noStyle();

  Set<String> allTags(Log log) => {...log.tags, ...main.tags, ...data.tags};

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('level', level, view: LogLevels.name(level))
      ..prop('data', this.data)
      ..prop('styledOpeningQuote', styledOpeningQuote)
      ..prop('styledClosingQuote', styledClosingQuote)
      ..prop('styledColon', styledColon)
      ..prop('styledEllipsis', styledEllipsis)
      ..prop('styledLineBreak', styledLineBreak)
      ..prop('styledPadding', styledPadding(1));
  }
}
