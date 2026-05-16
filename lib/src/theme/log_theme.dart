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

  AnsiPair get openingQuoteAnsiPair =>
      AnsiPair(main.openingQuote, data.quotesStyle);

  String get styledClosingQuote => data.quotesStyle(main.closingQuote);

  AnsiPair get closingQuoteAnsiPair =>
      AnsiPair(main.closingQuote, data.quotesStyle);

  String get styledColon => data.colonStyle(main.colon);

  AnsiPair get colonAnsiPair => AnsiPair(main.colon, data.colonStyle);

  String get styledEllipsis => data.ellipsisStyle(main.ellipsis);

  AnsiPair get ellipsisAnsiPair => AnsiPair(main.ellipsis, data.ellipsisStyle);

  String get styledLineBreak => data.lineBreakStyle(main.lineBreak);

  AnsiPair get lineBreakAnsiPair =>
      AnsiPair(main.lineBreak, data.lineBreakStyle);

  String get styledPadding => data.paddingStyle(main.padding);

  AnsiPair get paddingAnsiPair => AnsiPair(main.padding, data.paddingStyle);

  String formatValue(String value) => main.valueFormatter(data, value);

  String formatMessage(String value) => main.messageFormatter(data, value);

  String formatIndex(int index) => main.indexFormatter(this, index);

  String formatCount(int count) => main.countFormatter(this, count);

  LogDepthTheme depthTheme(int depth) =>
      data.depthThemes[depth % data.depthThemes.length];

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
      ..prop('styledPadding', styledPadding);
  }
}
