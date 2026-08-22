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

  /// Прогоняет [value] через value-форматтер темы.
  ///
  /// С [escapeAnsiCodes] сырой текст сначала показывается, а не
  /// отправляется: последовательность печатается частями
  /// (`[CSI 2 ED]forged`), и `ESC` в результате не остаётся ни одного —
  /// сформировать управляющую последовательность больше нечем. Форматтер
  /// темы работает уже по инертному тексту, а стили ложатся поверх.
  ///
  /// Порядок именно такой и обратным быть не может: после стилизации
  /// собственные коды темы от чужих не отличить.
  String formatValue(String value, {required bool escapeAnsiCodes}) =>
      main.valueFormatter(this, _safe(value, escapeAnsiCodes));

  /// Прогоняет [value] через message-форматтер темы. См. [formatValue].
  String formatMessage(String value, {required bool escapeAnsiCodes}) =>
      main.messageFormatter(this, _safe(value, escapeAnsiCodes));

  /// Текст без управляющих последовательностей, если режим включён.
  ///
  /// Проверка на `ESC` — не микрооптимизация: `ansiShowEscapeSequences()`
  /// каждый раз гоняет regex по всей строке, а подавляющее большинство
  /// значений в логе никаких кодов не содержит.
  static String _safe(String value, bool escapeAnsiCodes) =>
      escapeAnsiCodes && value.contains('\x1B')
          ? value.ansiShowEscapeSequences()
          : value;

  String formatIndex(int index) => main.indexFormatter(this, index);

  String formatCount(int count) => main.countFormatter(this, count);

  String formatCycle(int levelsUp) => main.cycleFormatter(this, levelsUp);

  String formatNumber(num value, String pattern) =>
      main.numberFormatter(this, value, pattern);

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
