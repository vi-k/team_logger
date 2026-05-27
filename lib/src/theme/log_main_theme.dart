import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../loggable/loggable.dart';
import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../preformatters/bb_code_formatter.dart';
import '../preformatters/control_code_formatter.dart';
import '../preformatters/log_pre_formatter.dart';
import '../printer/extensions.dart';

part 'log_theme_data.dart';
part 'log_style.dart';
part 'log_theme.dart';

typedef LogThemeFormatter<T extends Object?> = String Function(
  LogTheme theme,
  T,
);

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
  final bool collectionShowLength;
  final bool collectionShowIndexes;
  final LogPreFormatter valueFormatter;
  final LogPreFormatter messageFormatter;
  final LogThemeFormatter<int> countFormatter;
  final LogThemeFormatter<int> indexFormatter;
  final Set<String> tags;
  final String errorTitle;
  final String stackTraceTitle;
  final bool stringInQuotes;

  LogMainTheme({
    LogThemeData verbose = LogThemeData.noColors,
    LogThemeData debug = LogThemeData.noColors,
    LogThemeData info = LogThemeData.noColors,
    LogThemeData warning = LogThemeData.noColors,
    LogThemeData error = LogThemeData.noColors,
    LogThemeData critical = LogThemeData.noColors,
    this.minLevel = LogLevels.all,
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
    this.collectionShowLength = true,
    this.collectionShowIndexes = true,
    this.valueFormatter = const ControlCodeFormatter(),
    this.messageFormatter = const BbCodeFormatter(),
    this.countFormatter = _defaultCountFormatter,
    this.indexFormatter = _defaultIndexFormatter,
    this.tags = const {},
    this.errorTitle = defaultErrorTitle,
    this.stackTraceTitle = defaultStackTraceTitle,
    this.stringInQuotes = true,
  })  : _verbose = verbose,
        _debug = debug,
        _info = info,
        _warning = warning,
        _error = error,
        _critical = critical,
        assert(!openingQuote.ansiHasEscapeCodes),
        assert(!closingQuote.ansiHasEscapeCodes),
        assert(!colon.ansiHasEscapeCodes),
        assert(!ellipsis.ansiHasEscapeCodes),
        assert(!lineBreak.ansiHasEscapeCodes),
        assert(!padding.ansiHasEscapeCodes),
        assert(padding.length == 1);

  const LogMainTheme._({
    LogThemeData verbose = LogThemeData.noColors,
    LogThemeData debug = LogThemeData.noColors,
    LogThemeData info = LogThemeData.noColors,
    LogThemeData warning = LogThemeData.noColors,
    LogThemeData error = LogThemeData.noColors,
    LogThemeData critical = LogThemeData.noColors,
    this.traceIdStyle = const ansi.NoStyle(),
    this.tagsStyle = const ansi.NoStyle(),
    this.hiddenStyle = const ansi.NoStyle(),
  })  : _verbose = verbose,
        _debug = debug,
        _info = info,
        _warning = warning,
        _error = error,
        _critical = critical,
        minLevel = LogLevels.all,
        openingQuote = defaultQuote,
        closingQuote = defaultQuote,
        colon = defaultColon,
        ellipsis = defaultEllipsis,
        lineBreak = defaultLineBreak,
        padding = defaultPadding,
        errorAlwaysOnNewLine = false,
        enumDotShorthand = true,
        collectionShowLength = true,
        collectionShowIndexes = true,
        valueFormatter = const ControlCodeFormatter(),
        messageFormatter = const BbCodeFormatter(),
        countFormatter = _defaultCountFormatter,
        indexFormatter = _defaultIndexFormatter,
        tags = const {'log'},
        errorTitle = defaultErrorTitle,
        stackTraceTitle = defaultStackTraceTitle,
        stringInQuotes = true;

  static const LogMainTheme noColors = LogMainTheme._();

  LogTheme get verbose => LogTheme._(this, LogLevels.verbose);

  LogTheme get debug => LogTheme._(this, LogLevels.debug);

  LogTheme get info => LogTheme._(this, LogLevels.info);

  LogTheme get warning => LogTheme._(this, LogLevels.warning);

  LogTheme get error => LogTheme._(this, LogLevels.error);

  LogTheme get critical => LogTheme._(this, LogLevels.critical);

  LogTheme operator [](int level) => switch (level) {
        LogLevels.verbose => verbose,
        LogLevels.debug => debug,
        LogLevels.info => info,
        LogLevels.warning => warning,
        LogLevels.error => error,
        LogLevels.critical => critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  LogThemeData _dataByLevel(int level) => switch (level) {
        LogLevels.verbose => _verbose,
        LogLevels.debug => _debug,
        LogLevels.info => _info,
        LogLevels.warning => _warning,
        LogLevels.error => _error,
        LogLevels.critical => _critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  static const _activeTraceIdStyle = ansi.rgb530;
  static const _inactiveTraceIdStyle = ansi.rgb210;

  static const _tagsStyle = ansi.gray5;
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
  );

  static final LogMainTheme defaultInactiveTheme = LogMainTheme._(
    verbose: LogThemeData.inactiveSeed(normal: ansi.gray5),
    debug: LogThemeData.inactiveSeed(normal: ansi.gray7),
    info: LogThemeData.inactiveSeed(normal: ansi.rgb123),
    warning: LogThemeData.inactiveSeed(normal: ansi.rgb320),
    error: LogThemeData.inactiveSeed(normal: ansi.rgb300),
    critical: LogThemeData.inactiveSeed(normal: ansi.rgb303),
    traceIdStyle: _inactiveTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static final LogMainTheme defaultInactiveTheme2 = LogMainTheme._(
    verbose: LogThemeData.inactiveSeed(normal: ansi.gray4),
    debug: LogThemeData.inactiveSeed(normal: ansi.gray6),
    info: LogThemeData.inactiveSeed(normal: ansi.rgb012),
    warning: LogThemeData.inactiveSeed(normal: ansi.rgb210),
    error: LogThemeData.inactiveSeed(normal: ansi.rgb200),
    critical: LogThemeData.inactiveSeed(normal: ansi.rgb202),
    traceIdStyle: _inactiveTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static String _defaultCountFormatter(LogTheme theme, int count) =>
      '₌${subscript(count)}';

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
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    LogPreFormatter? valueFormatter,
    LogPreFormatter? messageFormatter,
    LogThemeFormatter<int>? countFormatter,
    LogThemeFormatter<int>? indexFormatter,
    Set<String>? tags,
    String? errorTitle,
    String? stackTraceTitle,
    bool? stringInQuotes,
  }) =>
      LogMainTheme(
        minLevel: minLevel ?? this.minLevel,
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
        collectionShowLength: collectionShowLength ?? this.collectionShowLength,
        collectionShowIndexes:
            collectionShowIndexes ?? this.collectionShowIndexes,
        valueFormatter: valueFormatter ?? this.valueFormatter,
        messageFormatter: messageFormatter ?? this.messageFormatter,
        countFormatter: countFormatter ?? this.countFormatter,
        indexFormatter: indexFormatter ?? this.indexFormatter,
        tags: tags ?? this.tags,
        errorTitle: errorTitle ?? this.errorTitle,
        stackTraceTitle: stackTraceTitle ?? this.stackTraceTitle,
        stringInQuotes: stringInQuotes ?? this.stringInQuotes,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('minLevel', minLevel, view: LogLevels.name(minLevel))
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
      ..prop('collectionShowLength', collectionShowLength)
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
      ..prop('tags', tags)
      ..prop('errorTitle', errorTitle)
      ..prop('stackTraceTitle', stackTraceTitle)
      ..prop('stringInQuotes', stringInQuotes);
  }
}
