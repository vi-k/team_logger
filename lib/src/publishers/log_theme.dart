import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../log_formatters/extensions.dart';
import '../loggable/log_data_theme.dart';
import '../loggable/loggable.dart';
import '../logger/log.dart';
import 'log_style.dart';

final class LogTheme with Loggable {
  final LogStyle normal;
  final LogStyle bold;
  final LogStyle dim;
  final LogStyle superDim;
  final LogStyle sequenceNum;
  final LogStyle levelName;
  final LogStyle time;
  final LogStyle path;
  final LogStyle tags;
  final LogStyle controlCodes;
  final LogStyle dataTitle;
  final LogStyle dataName;
  final LogStyle dataKey;
  final LogStyle dataIndex;
  final LogStyle dataValue;
  final LogStyle dataUnits;
  final List<LogStyle> dataLevels;
  final LogStyle punctuation;
  final LogPunctuation colon;
  final LogPunctuation ellipsis;
  final LogPunctuation lineBreak;
  final LogPunctuation padding;
  final int? maxLength;
  final int? maxLines;

  LogTheme({
    this.normal = LogStyle.terminalColors,
    LogStyle? bold,
    LogStyle? dim,
    LogStyle? superDim,
    LogStyle? sequenceNum,
    LogStyle? levelName,
    LogStyle? time,
    LogStyle? path,
    LogStyle? tags,
    LogStyle? controlCodes,
    LogStyle? paddingStyle,
    LogStyle? dataTitle,
    LogStyle? dataName,
    LogStyle? dataKey,
    LogStyle? dataIndex,
    LogStyle? dataValue,
    LogStyle? dataUnits,
    List<LogStyle>? dataLevels,
    LogStyle? punctuation,
    String colon = ':',
    LogStyle? colonStyle,
    String ellipsis = '…',
    LogStyle? ellipsisStyle,
    String lineBreak = '-',
    LogStyle? lineBreakStyle,
    String padding = ' ',
    this.maxLength,
    this.maxLines,
  })  : assert(maxLength == null || maxLength >= 0),
        assert(maxLines == null || maxLines >= 1),
        bold = bold ??
            normal.copyWith(
              verbose: normal.verbose.bold,
              debug: normal.debug.bold,
              info: normal.info.bold,
              warning: normal.warning.bold,
              error: normal.error.bold,
              critical: normal.critical.bold,
            ),
        dim = dim ??
            normal.copyWith(
              verbose: normal.verbose.dim,
              debug: normal.debug.dim,
              info: normal.info.dim,
              warning: normal.warning.dim,
              error: normal.error.dim,
              critical: normal.critical.dim,
            ),
        superDim = superDim ??
            normal.copyWith(
              verbose: normal.verbose.dim,
              debug: normal.debug.dim,
              info: normal.info.dim,
              warning: normal.warning.dim,
              error: normal.error.dim,
              critical: normal.critical.dim,
            ),
        sequenceNum = sequenceNum ??
            const LogStyle.only(
              ansi.Style(foreground: _tagColor),
            ),
        levelName = levelName ??
            normal.copyWith(
              verbose: ansi.Style(
                background: normal.verbose.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
              debug: ansi.Style(
                background: normal.debug.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
              info: ansi.Style(
                background: normal.info.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
              warning: ansi.Style(
                background: normal.warning.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
              error: ansi.Style(
                background: normal.error.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
              critical: ansi.Style(
                background: normal.critical.foregroundColor,
                foreground: ansi.Color256.gray0,
              ),
            ),
        time = time ?? LogStyle.noColors,
        path = path ?? LogStyle.noColors,
        tags = tags ??
            const LogStyle.only(
              ansi.Style(foreground: _tagColor),
            ),
        controlCodes = controlCodes ?? LogStyle.noColors,
        dataTitle = dataTitle ?? LogStyle.noColors,
        dataName = dataName ?? LogStyle.noColors,
        dataKey = dataKey ?? LogStyle.noColors,
        dataIndex = dataIndex ?? LogStyle.noColors,
        dataValue = dataValue ?? LogStyle.noColors,
        dataUnits = dataUnits ?? LogStyle.noColors,
        dataLevels = dataLevels ?? [LogStyle.noColors],
        punctuation = punctuation ?? LogStyle.noColors,
        assert(!colon.ansiHasEscapeCodes),
        colon = LogPunctuation(colon, style: colonStyle ?? punctuation),
        assert(!ellipsis.ansiHasEscapeCodes),
        ellipsis =
            LogPunctuation(ellipsis, style: ellipsisStyle ?? punctuation),
        assert(!lineBreak.ansiHasEscapeCodes),
        lineBreak =
            LogPunctuation(lineBreak, style: lineBreakStyle ?? punctuation),
        assert(!padding.ansiHasEscapeCodes),
        assert(padding.length == 1),
        padding = LogPunctuation(padding, style: paddingStyle ?? punctuation);

  const LogTheme._raw({
    required this.normal,
    required this.bold,
    required this.dim,
    required this.superDim,
    required this.sequenceNum,
    required this.levelName,
    required this.time,
    required this.path,
    required this.tags,
    required this.controlCodes,
    required this.dataTitle,
    required this.dataName,
    required this.dataKey,
    required this.dataIndex,
    required this.dataValue,
    required this.dataUnits,
    required this.dataLevels,
    required this.punctuation,
    required this.colon,
    required this.ellipsis,
    required this.lineBreak,
    required this.padding,
    required this.maxLength,
    required this.maxLines,
  });

  static const LogTheme noColorsTheme = LogTheme._raw(
    normal: LogStyle.noColors,
    bold: LogStyle.noColors,
    dim: LogStyle.noColors,
    superDim: LogStyle.noColors,
    sequenceNum: LogStyle.noColors,
    levelName: LogStyle.noColors,
    time: LogStyle.noColors,
    path: LogStyle.noColors,
    tags: LogStyle.noColors,
    controlCodes: LogStyle.noColors,
    dataTitle: LogStyle.noColors,
    dataName: LogStyle.noColors,
    dataKey: LogStyle.noColors,
    dataIndex: LogStyle.noColors,
    dataValue: LogStyle.noColors,
    dataUnits: LogStyle.noColors,
    dataLevels: [LogStyle.noColors],
    punctuation: LogStyle.noColors,
    colon: LogPunctuation(':'),
    ellipsis: LogPunctuation('…'),
    lineBreak: LogPunctuation('-'),
    padding: LogPunctuation(' '),
    maxLength: null,
    maxLines: null,
  );

  static const _black = ansi.Color256.gray0;

  static const _normalVerboseColor = ansi.Color256.gray7;
  static const _normalDebugColor = ansi.Color256.gray11;
  static const _normalInfoColor = ansi.Color256.rgb233;
  static const _normalWarningColor = ansi.Color256.rgb430;
  static const _normalErrorColor = ansi.Color256.rgb411;
  static const _normalCriticalColor = ansi.Color256.rgb414;

  static const _activeVerboseColor = ansi.Color256.gray10;
  static const _activeDebugColor = ansi.Color256.gray15;
  static const _activeInfoColor = ansi.Color256.rgb344;
  static const _activeWarningColor = ansi.Color256.rgb540;
  static const _activeErrorColor = ansi.Color256.rgb511;
  static const _activeCriticalColor = ansi.Color256.rgb515;

  static const _dimVerboseColor = ansi.Color256.gray5;
  static const _dimDebugColor = ansi.Color256.gray8;
  static const _dimInfoColor = ansi.Color256.rgb122;
  static const _dimWarningColor = ansi.Color256.rgb320;
  static const _dimErrorColor = ansi.Color256.rgb311;
  static const _dimCriticalColor = ansi.Color256.rgb313;

  static const _superDimVerboseColor = ansi.Color256.gray4;
  static const _superDimDebugColor = ansi.Color256.gray4;
  static const _superDimInfoColor = ansi.Color256.rgb011;
  static const _superDimWarningColor = ansi.Color256.rgb210;
  static const _superDimErrorColor = ansi.Color256.rgb200;
  static const _superDimCriticalColor = ansi.Color256.rgb202;

  static const _verbosePunctuationColor = ansi.Color256.rgb023;
  static const _debugPunctuationColor = ansi.Color256.rgb034;
  static const _punctuationColor = ansi.Color256.rgb045;
  static const _tagColor = ansi.Color256.gray5;

  static const _normalStyle = LogStyle(
    verbose: ansi.Style(foreground: _normalVerboseColor),
    debug: ansi.Style(foreground: _normalDebugColor),
    info: ansi.Style(foreground: _normalInfoColor),
    warning: ansi.Style(foreground: _normalWarningColor),
    error: ansi.Style(foreground: _normalErrorColor),
    critical: ansi.Style(foreground: _normalCriticalColor),
  );
  static const _activeStyle = LogStyle(
    verbose: ansi.Style(foreground: _activeVerboseColor),
    debug: ansi.Style(foreground: _activeDebugColor),
    info: ansi.Style(foreground: _activeInfoColor),
    warning: ansi.Style(foreground: _activeWarningColor),
    error: ansi.Style(foreground: _activeErrorColor),
    critical: ansi.Style(foreground: _activeCriticalColor),
  );
  static const _boldStyle = LogStyle(
    verbose: ansi.Style(foreground: _activeVerboseColor, bold: true),
    debug: ansi.Style(foreground: _activeDebugColor, bold: true),
    info: ansi.Style(foreground: _activeInfoColor, bold: true),
    warning: ansi.Style(foreground: _activeWarningColor, bold: true),
    error: ansi.Style(foreground: _activeErrorColor, bold: true),
    critical: ansi.Style(foreground: _activeCriticalColor, bold: true),
  );
  static const _dimStyle = LogStyle(
    verbose: ansi.Style(foreground: _dimVerboseColor),
    debug: ansi.Style(foreground: _dimDebugColor),
    info: ansi.Style(foreground: _dimInfoColor),
    warning: ansi.Style(foreground: _dimWarningColor),
    error: ansi.Style(foreground: _dimErrorColor),
    critical: ansi.Style(foreground: _dimCriticalColor),
  );
  static const _superDimStyle = LogStyle(
    verbose: ansi.Style(foreground: _superDimVerboseColor),
    debug: ansi.Style(foreground: _superDimDebugColor),
    info: ansi.Style(foreground: _superDimInfoColor),
    warning: ansi.Style(foreground: _superDimWarningColor),
    error: ansi.Style(foreground: _superDimErrorColor),
    critical: ansi.Style(foreground: _superDimCriticalColor),
  );
  static const _punctuationStyle = LogStyle.only(
    verbose: ansi.Style(foreground: _verbosePunctuationColor),
    debug: ansi.Style(foreground: _debugPunctuationColor),
    ansi.Style(foreground: _punctuationColor),
  );
  static const _tagStyle = LogStyle(
    verbose: ansi.Style(foreground: _tagColor),
    debug: ansi.Style(foreground: _tagColor),
    info: ansi.Style(foreground: _tagColor),
    warning: ansi.Style(foreground: _tagColor),
    error: ansi.Style(foreground: _tagColor),
    critical: ansi.Style(foreground: _tagColor),
  );

  static const LogTheme defaultTheme = LogTheme._raw(
    normal: _normalStyle,
    bold: _boldStyle,
    dim: _dimStyle,
    superDim: _superDimStyle,
    sequenceNum: _tagStyle,
    levelName: LogStyle(
      verbose: ansi.Style(
        background: _normalVerboseColor,
        foreground: _black,
      ),
      debug: ansi.Style(
        background: _normalDebugColor,
        foreground: _black,
      ),
      info: ansi.Style(
        background: _normalInfoColor,
        foreground: _black,
      ),
      warning: ansi.Style(
        background: _normalWarningColor,
        foreground: _black,
      ),
      error: ansi.Style(
        background: _normalErrorColor,
        foreground: _black,
      ),
      critical: ansi.Style(
        background: _normalCriticalColor,
        foreground: _black,
      ),
    ),
    time: LogStyle.noColors,
    path: _boldStyle,
    tags: _tagStyle,
    controlCodes: _punctuationStyle,
    dataTitle: LogStyle(
      verbose: ansi.Style(
        foreground: _black,
        background: _dimVerboseColor,
      ),
      debug: ansi.Style(
        foreground: _black,
        background: _dimDebugColor,
      ),
      info: ansi.Style(
        foreground: _black,
        background: _dimInfoColor,
      ),
      warning: ansi.Style(
        foreground: _black,
        background: _dimWarningColor,
      ),
      error: ansi.Style(
        foreground: _black,
        background: _dimErrorColor,
      ),
      critical: ansi.Style(
        foreground: _black,
        background: _dimCriticalColor,
      ),
    ),
    dataName: LogStyle.noColors,
    dataKey: _activeStyle,
    dataIndex: _dimStyle,
    dataValue: _normalStyle,
    dataUnits: _dimStyle,
    dataLevels: [
      LogStyle.only(
        verbose: ansi.Style(foreground: ansi.Color256.rgb320, bold: true),
        debug: ansi.Style(foreground: ansi.Color256.rgb430, bold: true),
        ansi.Style(foreground: ansi.Color256.rgb530, bold: true),
      ),
      LogStyle.only(
        verbose: ansi.Style(foreground: ansi.Color256.rgb230, bold: true),
        debug: ansi.Style(foreground: ansi.Color256.rgb240, bold: true),
        ansi.Style(foreground: ansi.Color256.rgb350, bold: true),
      ),
      LogStyle.only(
        verbose: ansi.Style(foreground: ansi.Color256.rgb024, bold: true),
        debug: ansi.Style(foreground: ansi.Color256.rgb034, bold: true),
        ansi.Style(foreground: ansi.Color256.rgb045, bold: true),
      ),
      LogStyle.only(
        verbose: ansi.Style(foreground: ansi.Color256.rgb224, bold: true),
        debug: ansi.Style(foreground: ansi.Color256.rgb325, bold: true),
        ansi.Style(foreground: ansi.Color256.rgb425, bold: true),
      ),
    ],
    punctuation: _punctuationStyle,
    colon: LogPunctuation(':', style: _punctuationStyle),
    ellipsis: LogPunctuation('…', style: _punctuationStyle),
    lineBreak: LogPunctuation('-', style: _punctuationStyle),
    padding: LogPunctuation(' '),
    maxLength: null,
    maxLines: null,
  );

  LogTheme copyWith({
    LogStyle? normal,
    LogStyle? bold,
    LogStyle? dim,
    LogStyle? superDim,
    LogStyle? sequenceNum,
    LogStyle? levelName,
    LogStyle? time,
    LogStyle? path,
    LogStyle? tags,
    LogStyle? controlCodes,
    LogStyle? dataTitle,
    LogStyle? dataName,
    LogStyle? dataKey,
    LogStyle? dataIndex,
    LogStyle? dataValue,
    LogStyle? dataUnits,
    List<LogStyle>? dataLevels,
    LogStyle? punctuation,
    String? colon,
    LogStyle? colonStyle,
    String? ellipsis,
    LogStyle? ellipsisStyle,
    String? lineBreak,
    LogStyle? lineBreakStyle,
    String? padding,
    LogStyle? paddingStyle,
    int? maxLength,
    int? maxLines,
  }) {
    assert(padding == null || padding.length == 1);

    return LogTheme._raw(
      normal: normal ?? this.normal,
      bold: bold ?? this.bold,
      dim: dim ?? this.dim,
      superDim: superDim ?? this.superDim,
      sequenceNum: sequenceNum ?? this.sequenceNum,
      levelName: levelName ?? this.levelName,
      time: time ?? this.time,
      path: path ?? this.path,
      tags: tags ?? this.tags,
      controlCodes: controlCodes ?? this.controlCodes,
      dataTitle: dataTitle ?? this.dataTitle,
      dataName: dataName ?? this.dataName,
      dataKey: dataKey ?? this.dataKey,
      dataIndex: dataIndex ?? this.dataIndex,
      dataValue: dataValue ?? this.dataValue,
      dataUnits: dataUnits ?? this.dataUnits,
      dataLevels: dataLevels ?? this.dataLevels,
      punctuation: punctuation ?? this.punctuation,
      colon: colon == null && colonStyle == null
          ? this.colon
          : this.colon.copyWith(string: colon, style: colonStyle),
      ellipsis: ellipsis == null && ellipsisStyle == null
          ? this.ellipsis
          : this.ellipsis.copyWith(string: ellipsis, style: ellipsisStyle),
      lineBreak: lineBreak == null && lineBreakStyle == null
          ? this.lineBreak
          : this.lineBreak.copyWith(string: lineBreak, style: lineBreakStyle),
      padding: padding == null && paddingStyle == null
          ? this.padding
          : this.padding.copyWith(string: padding, style: paddingStyle),
      maxLength: maxLength ?? this.maxLength,
      maxLines: maxLines ?? this.maxLines,
    );
  }

  LogDataTheme toDataTheme(int level) => LogDataTheme(
        title: dataTitle[level],
        name: dataName[level],
        key: dataKey[level],
        index: dataIndex[level],
        value: dataValue[level],
        units: dataUnits[level],
        levels: dataLevels.map((s) => s[level]).toList(),
        ellipsis: ellipsis.toAnsiStyled(level),
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
          ..prop('normal', normal)
          ..prop('bold', bold)
          ..prop('dim', dim)
          ..prop('superDim', superDim)
          ..prop('sequenceNum', sequenceNum)
          ..prop('levelName', levelName)
          ..prop('time', time)
          ..prop('path', path)
          ..prop('tags', tags)
          ..prop('controlCodes', controlCodes)
          ..prop('dataTitle', dataTitle)
          ..prop('dataName', dataName)
          ..prop('dataKey', dataKey)
          ..prop('dataIndex', dataIndex)
          ..prop('dataValue', dataValue)
          ..prop('dataUnits', dataUnits)
          ..prop('dataLevels', dataLevels)
          ..prop('punctuation', punctuation)
          ..prop('colon', colon)
          ..prop('ellipsis', ellipsis)
          ..prop('lineBreak', lineBreak)
          ..prop('padding', padding)
          ..prop('maxLength', maxLength)
          ..prop('maxLines', maxLines)
        //
        ;
  }
}

final class LogPunctuation with Loggable {
  final String _string;
  final LogStyle style;

  const LogPunctuation(
    this._string, {
    LogStyle? style,
  }) : style = style ?? LogStyle.noColors;

  bool get isEmpty => _string.isEmpty;

  bool get isNotEmpty => _string.isNotEmpty;

  int get length => _string.length;

  String call(Log log) => style[log.level](_string);

  LogPunctuation copyWith({
    String? string,
    LogStyle? style,
  }) =>
      LogPunctuation(
        string ?? _string,
        style: style ?? this.style,
      );

  AnsiStyled toAnsiStyled(int level) => AnsiStyled(_string, style[level]);

  @override
  String toString() => '$LogPunctuation($_string)';

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('string', _string, showName: false)
      ..prop('style', style);
  }
}
