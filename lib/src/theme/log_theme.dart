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

  /// Runs [value] through the theme's value formatter.
  ///
  /// With [escapeAnsiCodes] the raw text is first shown rather than sent:
  /// a sequence is printed as its parts (`[CSI 2 ED]forged`) and no ESC is
  /// left in the result, so there is nothing left to form a control
  /// sequence out of. The theme's formatter then works on inert text, and
  /// the styling goes on top.
  ///
  /// The order cannot be the other way round: once the theme has styled
  /// the text, its own codes cannot be told from injected ones.
  String formatValue(String value, {required bool escapeAnsiCodes}) =>
      main.valueFormatter(this, _safe(value, escapeAnsiCodes));

  /// Runs [value] through the theme's message formatter. See [formatValue].
  String formatMessage(String value, {required bool escapeAnsiCodes}) =>
      main.messageFormatter(this, _safe(value, escapeAnsiCodes));

  /// The text with its control sequences shown, when the mode is on.
  ///
  /// The ESC check is not a micro-optimization: `ansiShowEscapeSequences()`
  /// runs a regex over the whole string every time, and the overwhelming
  /// majority of logged values carry no codes at all.
  static String _safe(String value, bool escapeAnsiCodes) =>
      escapeAnsiCodes && value.contains('\x1B')
          ? value.ansiShowEscapeSequences()
          : value;

  String formatIndex(int index) => main.indexFormatter(this, index);

  String formatCount(int count) => main.countFormatter(this, count);

  String formatCycle(int levelsUp) => main.cycleFormatter(this, levelsUp);

  String formatNumber(num value, String pattern) =>
      main.numberFormatter(this, value, pattern);

  // An empty depthThemes degrades to the style-less variant rather than
  // breaking the formatting of the very first object.
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
