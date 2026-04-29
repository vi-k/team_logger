import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../log_preformatters/bb_code_formatter.dart';
import '../log_preformatters/control_code_formatter.dart';
import '../log_preformatters/log_pre_formatter.dart';
import '../loggable/loggable.dart';
import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../printer/extensions.dart';

part 'log_level_theme.dart';
part 'log_style.dart';

typedef LogThemeFormatter<T extends Object?> = String Function(
  LogLevelTheme theme,
  T,
);

final class LogTheme with Loggable {
  static const String defaultQuote = '"';
  static const String defaultColon = ':';
  static const String defaultEllipsis = '…';
  static const String defaultLineBreak = '-';
  static const String defaultPadding = ' ';

  final int minLevel;
  final LogLevelTheme verbose;
  final LogLevelTheme debug;
  final LogLevelTheme info;
  final LogLevelTheme warning;
  final LogLevelTheme error;
  final LogLevelTheme critical;
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
  final LogThemeFormatter<int> countFormatter;
  final LogThemeFormatter<int> indexFormatter;
  final Set<String> tags;

  LogTheme({
    this.minLevel = LogLevels.all,
    this.verbose = LogLevelTheme.noColors,
    this.debug = LogLevelTheme.noColors,
    this.info = LogLevelTheme.noColors,
    this.warning = LogLevelTheme.noColors,
    this.error = LogLevelTheme.noColors,
    this.critical = LogLevelTheme.noColors,
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
    this.countFormatter = _defaultCountFormatter,
    this.indexFormatter = _defaultIndexFormatter,
    this.tags = const {},
  })  : assert(!openingQuote.ansiHasEscapeCodes),
        assert(!closingQuote.ansiHasEscapeCodes),
        assert(!colon.ansiHasEscapeCodes),
        assert(!ellipsis.ansiHasEscapeCodes),
        assert(!lineBreak.ansiHasEscapeCodes),
        assert(!padding.ansiHasEscapeCodes),
        assert(padding.length == 1);

  const LogTheme._({
    this.verbose = LogLevelTheme.noColors,
    this.debug = LogLevelTheme.noColors,
    this.info = LogLevelTheme.noColors,
    this.warning = LogLevelTheme.noColors,
    this.error = LogLevelTheme.noColors,
    this.critical = LogLevelTheme.noColors,
    this.traceIdStyle = const ansi.NoStyle(),
    this.tagsStyle = const ansi.NoStyle(),
    this.hiddenStyle = const ansi.NoStyle(),
  })  : minLevel = LogLevels.all,
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
        countFormatter = _defaultCountFormatter,
        indexFormatter = _defaultIndexFormatter,
        tags = const {'log'};

  void registerLevelThemes() {
    verbose.attach(this);
    debug.attach(this);
    info.attach(this);
    warning.attach(this);
    error.attach(this);
    critical.attach(this);
  }

  LogLevelTheme operator [](int level) => switch (level) {
        LogLevels.verbose => verbose,
        LogLevels.debug => debug,
        LogLevels.info => info,
        LogLevels.warning => warning,
        LogLevels.error => error,
        LogLevels.critical => critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  static const LogTheme noColors = LogTheme._();

  static const _activeTraceIdStyle = ansi.rgb530;
  static const _inactiveTraceIdStyle = ansi.rgb210;

  static const _tagsStyle = ansi.gray5;
  static const _hiddenStyle =
      ansi.Style(foreground: ansi.Color256.gray3, invisible: true);

  static final LogTheme defaultActiveTheme = LogTheme._(
    verbose: LogLevelTheme.gray8,
    debug: LogLevelTheme.gray12,
    info: LogLevelTheme.rgb234,
    warning: LogLevelTheme.rgb431,
    error: LogLevelTheme.rgb411,
    critical: LogLevelTheme.rgb414,
    traceIdStyle: _activeTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static final LogTheme defaultInactiveTheme = LogTheme._(
    verbose: LogLevelTheme.inactiveSeed(normal: ansi.gray4),
    debug: LogLevelTheme.inactiveSeed(normal: ansi.gray6),
    // info: LogLevelTheme.inactiveSeed(normal: ansi.rgb123),
    info: LogLevelTheme.inactiveSeed(normal: ansi.rgb012),
    // warning: LogLevelTheme.inactiveSeed(normal: ansi.rgb320),
    warning: LogLevelTheme.inactiveSeed(normal: ansi.rgb210),
    // error: LogLevelTheme.inactiveSeed(normal: ansi.rgb300),
    error: LogLevelTheme.inactiveSeed(normal: ansi.rgb200),
    // critical: LogLevelTheme.inactiveSeed(normal: ansi.rgb303),
    critical: LogLevelTheme.inactiveSeed(normal: ansi.rgb202),
    traceIdStyle: _inactiveTraceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static String _defaultCountFormatter(LogLevelTheme theme, int count) =>
      '₌${subscript(count)} ';

  static String _defaultIndexFormatter(LogLevelTheme theme, int index) =>
      '${subscript(index)}${theme.common.colon}';

  static final _reDigits = RegExp('[0-9]');
  static final _normal0Code = '0'.codeUnitAt(0);
  static final _small0Code = '₀'.codeUnitAt(0);
  static String subscript(int n) => n.toString().replaceAllMapped(
        _reDigits,
        (m) => String.fromCharCode(
          m[0]!.codeUnitAt(0) - _normal0Code + _small0Code,
        ),
      );

  LogTheme copyWith({
    int? minLevel,
    LogLevelTheme? verbose,
    LogLevelTheme? debug,
    LogLevelTheme? info,
    LogLevelTheme? warning,
    LogLevelTheme? error,
    LogLevelTheme? critical,
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
    String? dataSectionName,
    bool? enumDotShorthand,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    LogThemeFormatter<int>? countFormatter,
    LogThemeFormatter<int>? indexFormatter,
    Set<String>? tags,
  }) =>
      LogTheme(
        minLevel: minLevel ?? this.minLevel,
        verbose: verbose ?? this.verbose,
        debug: debug ?? this.debug,
        info: info ?? this.info,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        critical: critical ?? this.critical,
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
        countFormatter: countFormatter ?? this.countFormatter,
        indexFormatter: indexFormatter ?? this.indexFormatter,
        tags: tags ?? this.tags,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('minLevel', minLevel)
      ..theme('verbose', verbose)
      ..theme('debug', debug)
      ..theme('info', info)
      ..theme('warning', warning)
      ..theme('error', error)
      ..theme('critical', critical)
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
      ..prop('tags', tags);
  }
}
