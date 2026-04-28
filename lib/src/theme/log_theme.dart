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
  final bool errorOnNewLine;
  final bool enumDotShorthand;
  final bool showCount;
  final bool showIndexes;
  final LogThemeFormatter<int> countFormatter;
  final LogThemeFormatter<int> indexFormatter;
  final Set<String> tags;

  LogTheme({
    this.verbose = LogLevelTheme.noColors,
    this.debug = LogLevelTheme.noColors,
    this.info = LogLevelTheme.noColors,
    this.warning = LogLevelTheme.noColors,
    this.error = LogLevelTheme.noColors,
    this.critical = LogLevelTheme.noColors,
    this.traceIdStyle = _traceIdStyle,
    this.tagsStyle = _tagsStyle,
    this.hiddenStyle = _hiddenStyle,
    this.openingQuote = defaultQuote,
    this.closingQuote = defaultQuote,
    this.colon = defaultColon,
    this.ellipsis = defaultEllipsis,
    this.lineBreak = defaultLineBreak,
    this.padding = defaultPadding,
    this.errorOnNewLine = false,
    this.enumDotShorthand = true,
    this.showCount = true,
    this.showIndexes = true,
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
  })  : openingQuote = defaultQuote,
        closingQuote = defaultQuote,
        colon = defaultColon,
        ellipsis = defaultEllipsis,
        lineBreak = defaultLineBreak,
        padding = defaultPadding,
        errorOnNewLine = false,
        enumDotShorthand = true,
        showCount = true,
        showIndexes = true,
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

  static const _traceIdStyle = ansi.rgb530;
  static const _tagsStyle = ansi.gray5;
  static const _hiddenStyle =
      ansi.Style(foreground: ansi.Color256.gray3, invisible: true);

  // inactive

  static const _inactiveVerboseNormalColor = ansi.Color256.gray5;
  static const _inactiveVerboseNormalStyle =
      ansi.Style(foreground: _inactiveVerboseNormalColor);

  static const _inactiveDebugNormalColor = ansi.Color256.gray7;
  static const _inactiveDebugNormalStyle =
      ansi.Style(foreground: _inactiveDebugNormalColor);

  static const _inactiveInfoNormalColor = ansi.Color256.rgb122;
  static const _inactiveInfoNormalStyle =
      ansi.Style(foreground: _inactiveInfoNormalColor);

  static const _inactiveWarningNormalColor = ansi.Color256.rgb320;
  static const _inactiveWarningNormalStyle =
      ansi.Style(foreground: _inactiveWarningNormalColor);

  static const _inactiveErrorNormalColor = ansi.Color256.rgb300;
  static const _inactiveErrorNormalStyle =
      ansi.Style(foreground: _inactiveErrorNormalColor);

  static const _inactiveCriticalNormalColor = ansi.Color256.rgb303;
  static const _inactiveCriticalNormalStyle =
      ansi.Style(foreground: _inactiveCriticalNormalColor);

  static final LogTheme defaultActiveTheme = LogTheme._(
    verbose: LogLevelTheme.gray8,
    debug: LogLevelTheme.gray12,
    info: LogLevelTheme.rgb234,
    warning: LogLevelTheme.rgb431,
    error: LogLevelTheme.rgb411,
    critical: LogLevelTheme.rgb414,
    traceIdStyle: _traceIdStyle,
    tagsStyle: _tagsStyle,
    hiddenStyle: _hiddenStyle,
  );

  static const LogTheme defaultInactiveTheme = LogTheme._(
    verbose: LogLevelTheme(
      normal: _inactiveVerboseNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveVerboseNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    debug: LogLevelTheme(
      normal: _inactiveDebugNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveDebugNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    info: LogLevelTheme(
      normal: _inactiveInfoNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveInfoNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    warning: LogLevelTheme(
      normal: _inactiveWarningNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveWarningNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    error: LogLevelTheme(
      normal: _inactiveErrorNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveErrorNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    critical: LogLevelTheme(
      normal: _inactiveCriticalNormalStyle,
      inverse: ansi.Style(
        foreground: LogLevelTheme._black,
        background: _inactiveCriticalNormalColor,
      ),
      bold: ansi.NoStyle(),
      emphasis: ansi.NoStyle(),
      dim: ansi.NoStyle(),
      punctuation: ansi.NoStyle(),
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        'success': ansi.NoStyle(),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      controlCodesStyle: ansi.NoStyle(),
      quotesStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      sectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBlockTheme: [
        LogDataBlockTheme(
          brackets: ansi.NoStyle(),
          description: ansi.NoStyle(),
          punctuation: ansi.NoStyle(),
        ),
      ],
      stackTraceActiveStyle: ansi.NoStyle(),
      stackTraceInactiveStyle: ansi.NoStyle(),
    ),
    traceIdStyle: _traceIdStyle,
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
    bool? errorOnNewLine,
    String? dataSectionName,
    bool? enumDotShorthand,
    bool? showCount,
    bool? showIndexes,
    LogThemeFormatter<int>? countFormatter,
    LogThemeFormatter<int>? indexFormatter,
    Set<String>? tags,
  }) =>
      LogTheme(
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
        errorOnNewLine: errorOnNewLine ?? this.errorOnNewLine,
        enumDotShorthand: enumDotShorthand ?? this.enumDotShorthand,
        showCount: showCount ?? this.showCount,
        showIndexes: showIndexes ?? this.showIndexes,
        countFormatter: countFormatter ?? this.countFormatter,
        indexFormatter: indexFormatter ?? this.indexFormatter,
        tags: tags ?? this.tags,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop(
        'verbose',
        verbose,
        showName: false,
        view: verbose.normal('verbose'),
      )
      ..prop(
        'debug',
        debug,
        showName: false,
        view: debug.normal('debug'),
      )
      ..prop(
        'info',
        info,
        showName: false,
        view: info.normal('info'),
      )
      ..prop(
        'warning',
        warning,
        showName: false,
        view: warning.normal('warning'),
      )
      ..prop(
        'error',
        error,
        showName: false,
        view: error.normal('error'),
      )
      ..prop(
        'critical',
        critical,
        showName: false,
        view: critical.normal('critical'),
      )
      ..style('traceIdStyle', null, traceIdStyle)
      ..style('tagsStyle', null, tagsStyle)
      ..style('hiddenStyle', null, hiddenStyle, showName: true)
      ..prop('openingQuote', openingQuote)
      ..prop('closingQuote', closingQuote)
      ..prop('colon', colon)
      ..prop('ellipsis', ellipsis)
      ..prop('lineBreak', lineBreak)
      ..prop('padding', padding)
      ..prop('errorOnNewLine', errorOnNewLine)
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('showCount', showCount)
      ..prop('showIndexes', showIndexes)
      ..prop('tags', tags);
  }
}
