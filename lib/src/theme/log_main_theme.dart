import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../loggable/loggable.dart';
import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../preformatters/bb_code_formatter.dart';
import '../preformatters/control_code_formatter.dart';
import '../preformatters/log_pre_formatter.dart';

part 'log_style.dart';
part 'log_styles.dart';
part 'log_theme.dart';
part 'log_theme_data.dart';

typedef LogThemeFormatter<T extends Object?> = String Function(
  LogTheme theme,
  T,
);

/// A theme's number formatter: it receives the value and the **opaque
/// pattern** from `LoggableConfig.intFormat`/`LoggableConfig.doubleFormat`
/// and returns the rendered string.
///
/// The package does not parse the pattern and defines no syntax for it —
/// the formatter does. See [LogMainTheme.numberFormatter].
typedef LogNumberFormatter = String Function(
  LogTheme theme,
  num value,
  String pattern,
);

/// The root theme: six per-level [LogThemeData]s plus shared styling
/// (quotes, ellipsis, message/value formatters, trace id and tag styles).
///
/// Ready-made themes: [defaultActiveTheme], [defaultInactiveTheme],
/// [noColors], [noColorsNoTags]. For custom colorless themes pass
/// `ansiCodesEnabled: false`.
///
/// The public constructor rejects ANSI escape codes in its textual punctuation
/// tokens with [ArgumentError]; [padding] must contain exactly one code unit.
///
/// In colorless themes [hiddenStyle] is a no-op, so "hidden" stretch
/// fillers (time/path/num repeated on continuation lines) show as plain
/// text — this is expected behavior.
final class LogMainTheme with Loggable {
  static const String defaultQuote = '"';
  static const String defaultColon = ':';
  static const String defaultEllipsis = '…';
  static const String defaultLineBreak = '-';
  static const String defaultPadding = ' ';
  static const String defaultErrorTitle = 'ERROR';
  static const String defaultStackTraceTitle = 'STACKTRACE';

  final LogThemeData _verbose;
  final LogThemeData _debug;
  final LogThemeData _info;
  final LogThemeData _warning;
  final LogThemeData _error;
  final LogThemeData _critical;

  final int minLevel;
  final Map<String, LogStyle> messageStyles;
  final ansi.Style traceIdStyle;
  final ansi.Style tagsStyle;
  final ansi.Style hiddenStyle;
  final String openingQuote;
  final String closingQuote;
  final String colon;
  final String ellipsis;
  final String lineBreak;
  final String padding;
  final bool errorAlwaysOnNewLine;
  final bool enumDotShorthand;
  final bool collectionShowCount;
  final bool collectionShowIndexes;
  final LogPreFormatter valueFormatter;
  final LogPreFormatter messageFormatter;
  final LogThemeFormatter<int> countFormatter;
  final LogThemeFormatter<int> indexFormatter;

  /// Renders a number whose `LoggableConfig.intFormat` or
  /// `LoggableConfig.doubleFormat` is set; the pattern arrives here exactly
  /// as it was written, together with the value.
  ///
  /// The default ignores the pattern and prints `value.toString()`: this
  /// package depends on no number formatter and knows no pattern syntax.
  /// Install one to make patterns work — for example over
  /// [`package:format`](https://pub.dev/packages/format), which is what the
  /// README documents:
  ///
  /// ```dart
  /// LogMainTheme.defaultActiveTheme.copyWith(
  ///   numberFormatter: (theme, value, pattern) => format(pattern, value),
  /// )
  /// ```
  ///
  /// An exception thrown here reaches the publisher that was rendering, the
  /// same way a throwing [Loggable.sanitizer] rule does.
  final LogNumberFormatter numberFormatter;
  final Set<String> tags;
  final String errorTitle;
  final String stackTraceTitle;
  final bool stringInQuotes;

  /// Излучает ли тема ANSI-коды. Для собственных «бесцветных» тем передайте
  /// `false`, чтобы принтер не добавлял служебные escape-коды.
  final bool ansiCodesEnabled;

  /// Форматтер маркера циклической ссылки; получает количество уровней
  /// вверх до объекта, на который указывает цикл. По умолчанию — `↺₂`.
  final LogThemeFormatter<int> cycleFormatter;

  /// Стиль маркера циклической ссылки.
  final ansi.Style cycleStyle;

  LogMainTheme({
    LogThemeData verbose = LogThemeData.noColors,
    LogThemeData debug = LogThemeData.noColors,
    LogThemeData info = LogThemeData.noColors,
    LogThemeData warning = LogThemeData.noColors,
    LogThemeData error = LogThemeData.noColors,
    LogThemeData critical = LogThemeData.noColors,
    this.minLevel = LogLevels.all,
    this.messageStyles = defaultMessageStyles,
    this.traceIdStyle = _activeTraceIdStyle,
    this.tagsStyle = _tagsStyle,
    this.hiddenStyle = _hiddenStyle,
    this.openingQuote = defaultQuote,
    this.closingQuote = defaultQuote,
    this.colon = defaultColon,
    this.ellipsis = defaultEllipsis,
    this.lineBreak = defaultLineBreak,
    this.padding = defaultPadding,
    this.errorAlwaysOnNewLine = false,
    this.enumDotShorthand = true,
    this.collectionShowCount = true,
    this.collectionShowIndexes = true,
    this.valueFormatter = const ControlCodeFormatter(),
    this.messageFormatter = const BbCodeFormatter(),
    this.countFormatter = _defaultCountFormatter,
    this.indexFormatter = _defaultIndexFormatter,
    this.numberFormatter = _defaultNumberFormatter,
    this.tags = const {},
    this.errorTitle = defaultErrorTitle,
    this.stackTraceTitle = defaultStackTraceTitle,
    this.stringInQuotes = true,
    this.ansiCodesEnabled = true,
    this.cycleFormatter = _defaultCycleFormatter,
    this.cycleStyle = const ansi.NoStyle(),
  })  : _verbose = verbose,
        _debug = debug,
        _info = info,
        _warning = warning,
        _error = error,
        _critical = critical {
    _validatePlainThemeToken(openingQuote, 'openingQuote');
    _validatePlainThemeToken(closingQuote, 'closingQuote');
    _validatePlainThemeToken(colon, 'colon');
    _validatePlainThemeToken(ellipsis, 'ellipsis');
    _validatePlainThemeToken(lineBreak, 'lineBreak');
    _validatePlainThemeToken(padding, 'padding');
    if (padding.length != 1) {
      throw ArgumentError.value(
        padding,
        'padding',
        'Must contain exactly one code unit',
      );
    }
  }

  const LogMainTheme._({
    LogThemeData verbose = LogThemeData.noColors,
    LogThemeData debug = LogThemeData.noColors,
    LogThemeData info = LogThemeData.noColors,
    LogThemeData warning = LogThemeData.noColors,
    LogThemeData error = LogThemeData.noColors,
    LogThemeData critical = LogThemeData.noColors,
    this.messageStyles = defaultMessageStyles,
    this.traceIdStyle = const ansi.NoStyle(),
    this.tagsStyle = const ansi.NoStyle(),
    this.hiddenStyle = const ansi.NoStyle(),
    this.ansiCodesEnabled = true,
    this.cycleStyle = const ansi.NoStyle(),
  })  : _verbose = verbose,
        _debug = debug,
        _info = info,
        _warning = warning,
        _error = error,
        _critical = critical,
        cycleFormatter = _defaultCycleFormatter,
        minLevel = LogLevels.all,
        openingQuote = defaultQuote,
        closingQuote = defaultQuote,
        colon = defaultColon,
        ellipsis = defaultEllipsis,
        lineBreak = defaultLineBreak,
        padding = defaultPadding,
        errorAlwaysOnNewLine = false,
        enumDotShorthand = true,
        collectionShowCount = true,
        collectionShowIndexes = true,
        valueFormatter = const ControlCodeFormatter(),
        messageFormatter = const BbCodeFormatter(),
        countFormatter = _defaultCountFormatter,
        indexFormatter = _defaultIndexFormatter,
        numberFormatter = _defaultNumberFormatter,
        tags = const {},
        errorTitle = defaultErrorTitle,
        stackTraceTitle = defaultStackTraceTitle,
        stringInQuotes = true;

  static const LogMainTheme noColors = LogMainTheme._(
    messageStyles: defaultNoColorsMessageStyles,
    ansiCodesEnabled: false,
  );

  static const LogMainTheme noColorsNoTags = LogMainTheme._(
    messageStyles: defaultNoColorsNoBbCodesMessageStyles,
    ansiCodesEnabled: false,
  );

  /// Кэш уровневых [LogTheme]: темы иммутабельны, а новый экземпляр на
  /// каждый лог ломал бы кэши, ключуемые по [LogTheme] (например, регулярку
  /// BbCodeFormatter), заставляя пересоздавать их на каждое сообщение.
  static final Expando<Map<int, LogTheme>> _levelThemeCache = Expando();

  LogTheme get verbose => this[LogLevels.verbose];

  LogTheme get debug => this[LogLevels.debug];

  LogTheme get info => this[LogLevels.info];

  LogTheme get warning => this[LogLevels.warning];

  LogTheme get error => this[LogLevels.error];

  LogTheme get critical => this[LogLevels.critical];

  LogTheme operator [](int level) {
    final cache = _levelThemeCache[this] ??= {};

    return cache[level] ??= switch (level) {
      LogLevels.verbose ||
      LogLevels.debug ||
      LogLevels.info ||
      LogLevels.warning ||
      LogLevels.error ||
      LogLevels.critical =>
        LogTheme._(this, level),
      _ => throw Exception('Unknown log level: $level'),
    };
  }

  LogThemeData _dataByLevel(int level) => switch (level) {
        LogLevels.verbose => _verbose,
        LogLevels.debug => _debug,
        LogLevels.info => _info,
        LogLevels.warning => _warning,
        LogLevels.error => _error,
        LogLevels.critical => _critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  static const _activeTraceIdStyle = ansi.Styles.rgb530;
  static const _inactiveTraceIdStyle = ansi.Styles.rgb210;

  static const _tagsStyle = ansi.Styles.gray5;
  static const _hiddenStyle =
      ansi.Style(foreground: ansi.Color256.rgb000, invisible: true);

  static final LogMainTheme defaultActiveTheme = LogMainTheme._(
    verbose: LogThemeData.gray8,
    debug: LogThemeData.gray12,
    info: LogThemeData.rgb234,
    warning: LogThemeData.rgb431,
    error: LogThemeData.rgb411,
    critical: LogThemeData.rgb414,
    traceIdStyle: _activeTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
    cycleStyle: ansi.Styles.rgb431,
  );

  static final LogMainTheme defaultInactiveTheme = LogMainTheme._(
    verbose: LogThemeData.inactiveSeed(normal: ansi.Styles.gray5),
    debug: LogThemeData.inactiveSeed(normal: ansi.Styles.gray7),
    info: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb123),
    warning: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb320),
    error: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb300),
    critical: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb303),
    traceIdStyle: _inactiveTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static final LogMainTheme defaultInactiveTheme2 = LogMainTheme._(
    verbose: LogThemeData.inactiveSeed(normal: ansi.Styles.gray4),
    debug: LogThemeData.inactiveSeed(normal: ansi.Styles.gray6),
    info: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb012),
    warning: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb210),
    error: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb200),
    critical: LogThemeData.inactiveSeed(normal: ansi.Styles.rgb202),
    traceIdStyle: _inactiveTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static const defaultMessageStyles = {
    'b': LogLazyStyle(_boldStyle),
    'signal': LogStyle(
      ansi.Style(
        background: ansi.Color256.rgb055,
        foreground: ansi.Color256.rgb000,
      ),
    ),
    'warning': LogLazyStyle(_warningStyle),
    'error': LogLazyStyle(_errorStyle),
  };

  static const Map<String, LogStyle> defaultNoColorsMessageStyles = {};

  static const Map<String, LogStyle> defaultNoColorsNoBbCodesMessageStyles = {
    'b': LogStyle(ansi.NoStyle()),
    'signal': LogStyle(ansi.NoStyle()),
    'success': LogStyle(ansi.NoStyle()),
    'warning': LogStyle(ansi.NoStyle()),
    'error': LogStyle(ansi.NoStyle()),
  };

  static ansi.Style _boldStyle(LogTheme theme) => theme.data.bold;

  static ansi.Style _errorStyle(LogTheme theme) => theme.main.error.data.normal;

  static ansi.Style _warningStyle(LogTheme theme) =>
      theme.main.warning.data.normal;

  static String _defaultCountFormatter(LogTheme theme, int count) =>
      '₌${subscript(count)}';

  static String _defaultNumberFormatter(
    LogTheme theme,
    num value,
    String pattern,
  ) =>
      value.toString();

  static String _defaultCycleFormatter(LogTheme theme, int levelsUp) =>
      '↺${subscript(levelsUp)}';

  static String _defaultIndexFormatter(LogTheme theme, int index) =>
      '${subscript(index)}${theme.main.colon}';

  static final _reDigits = RegExp('[0-9]');
  static final _normal0Code = '0'.codeUnitAt(0);
  static final _small0Code = '₀'.codeUnitAt(0);
  static String subscript(int n) => n.toString().replaceAllMapped(
        _reDigits,
        (m) => String.fromCharCode(
          m[0]!.codeUnitAt(0) - _normal0Code + _small0Code,
        ),
      );

  LogMainTheme copyWith({
    int? minLevel,
    Map<String, LogStyle>? messageStyles,
    LogThemeData? verbose,
    LogThemeData? debug,
    LogThemeData? info,
    LogThemeData? warning,
    LogThemeData? error,
    LogThemeData? critical,
    ansi.Style? traceIdStyle,
    ansi.Style? tagsStyle,
    ansi.Style? hiddenStyle,
    String? openingQuote,
    String? closingQuote,
    String? colon,
    String? ellipsis,
    String? lineBreak,
    String? padding,
    bool? errorAlwaysOnNewLine,
    bool? enumDotShorthand,
    bool? collectionShowCount,
    bool? collectionShowIndexes,
    LogPreFormatter? valueFormatter,
    LogPreFormatter? messageFormatter,
    LogThemeFormatter<int>? countFormatter,
    LogThemeFormatter<int>? indexFormatter,
    LogNumberFormatter? numberFormatter,
    Set<String>? tags,
    String? errorTitle,
    String? stackTraceTitle,
    bool? stringInQuotes,
    bool? ansiCodesEnabled,
    LogThemeFormatter<int>? cycleFormatter,
    ansi.Style? cycleStyle,
  }) =>
      LogMainTheme(
        minLevel: minLevel ?? this.minLevel,
        messageStyles: messageStyles ?? this.messageStyles,
        verbose: verbose ?? _verbose,
        debug: debug ?? _debug,
        info: info ?? _info,
        warning: warning ?? _warning,
        error: error ?? _error,
        critical: critical ?? _critical,
        traceIdStyle: traceIdStyle ?? this.traceIdStyle,
        tagsStyle: tagsStyle ?? this.tagsStyle,
        hiddenStyle: hiddenStyle ?? this.hiddenStyle,
        openingQuote: openingQuote ?? this.openingQuote,
        closingQuote: closingQuote ?? this.closingQuote,
        colon: colon ?? this.colon,
        ellipsis: ellipsis ?? this.ellipsis,
        lineBreak: lineBreak ?? this.lineBreak,
        padding: padding ?? this.padding,
        errorAlwaysOnNewLine: errorAlwaysOnNewLine ?? this.errorAlwaysOnNewLine,
        enumDotShorthand: enumDotShorthand ?? this.enumDotShorthand,
        collectionShowCount: collectionShowCount ?? this.collectionShowCount,
        collectionShowIndexes:
            collectionShowIndexes ?? this.collectionShowIndexes,
        valueFormatter: valueFormatter ?? this.valueFormatter,
        messageFormatter: messageFormatter ?? this.messageFormatter,
        countFormatter: countFormatter ?? this.countFormatter,
        indexFormatter: indexFormatter ?? this.indexFormatter,
        numberFormatter: numberFormatter ?? this.numberFormatter,
        tags: tags ?? this.tags,
        errorTitle: errorTitle ?? this.errorTitle,
        stackTraceTitle: stackTraceTitle ?? this.stackTraceTitle,
        stringInQuotes: stringInQuotes ?? this.stringInQuotes,
        ansiCodesEnabled: ansiCodesEnabled ?? this.ansiCodesEnabled,
        cycleFormatter: cycleFormatter ?? this.cycleFormatter,
        cycleStyle: cycleStyle ?? this.cycleStyle,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('minLevel', minLevel, view: LogLevels.name(minLevel))
      ..lazyStyles('messageStyles', messageStyles)
      ..theme('verbose', _verbose)
      ..theme('debug', _debug)
      ..theme('info', _info)
      ..theme('warning', _warning)
      ..theme('error', _error)
      ..theme('critical', _critical)
      ..style('traceIdStyle', null, traceIdStyle)
      ..style('tagsStyle', null, tagsStyle)
      ..style('hiddenStyle', null, hiddenStyle, showName: true)
      ..prop('openingQuote', openingQuote)
      ..prop('closingQuote', closingQuote)
      ..prop('colon', colon)
      ..prop('ellipsis', ellipsis)
      ..prop('lineBreak', lineBreak)
      ..prop('padding', padding)
      ..prop('errorAlwaysOnNewLine', errorAlwaysOnNewLine)
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('collectionShowCount', collectionShowCount)
      ..prop('collectionShowIndexes', collectionShowIndexes)
      ..prop('valueFormatter', valueFormatter)
      ..prop('messageFormatter', messageFormatter)
      ..prop(
        'countFormatter',
        countFormatter,
        view: LoggableView.convert(
          (value, theme, _) => '${theme.styledOpeningQuote}'
              '${countFormatter(theme, 4)}'
              '${theme.styledClosingQuote}',
        ),
      )
      ..prop(
        'indexFormatter',
        indexFormatter,
        view: LoggableView.convert(
          (value, theme, _) => '${theme.styledOpeningQuote}'
              '${indexFormatter(theme, 3)}'
              '${theme.styledClosingQuote}',
        ),
      )
      // Без сэмпла, в отличие от соседей: любой пример шаблона был бы
      // синтаксисом конкретного форматтера, а пакет как раз это знание
      // и не держит.
      ..prop('numberFormatter', numberFormatter)
      ..prop('tags', tags)
      ..prop('errorTitle', errorTitle)
      ..prop('stackTraceTitle', stackTraceTitle)
      ..prop('stringInQuotes', stringInQuotes);
  }
}

void _validatePlainThemeToken(String value, String name) {
  if (value.ansiHasEscapeCodes) {
    throw ArgumentError.value(
      value,
      name,
      'Must not contain ANSI escape codes',
    );
  }
}
