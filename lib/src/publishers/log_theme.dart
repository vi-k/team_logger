import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../log_formatters/extensions.dart';
import '../loggable/log_data_theme.dart';
import '../logger/log.dart';
import 'log_style.dart';

final class LogTheme {
  final LogStyle normal;
  final LogStyle bold;
  final LogStyle dim;
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
  final LogStyle dataDim;
  final LogStyle dataLevel0;
  final LogStyle dataLevel1;
  final LogStyle dataLevel2;
  final LogStyle dataLevel3;
  final LogStyle dataLevelN;
  final LogStyle punctuation;
  final LogPunctuation colon;
  final LogPunctuation ellipsis;
  final LogPunctuation lineBreak;
  final LogPunctuation padding;
  final int? maxLength;
  final int? maxLines;

  LogTheme({
    required this.normal,
    LogStyle? bold,
    LogStyle? dim,
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
    LogStyle? dataDim,
    LogStyle? dataLevel0,
    LogStyle? dataLevel1,
    LogStyle? dataLevel2,
    LogStyle? dataLevel3,
    LogStyle? dataLevelN,
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
        sequenceNum = sequenceNum ??
            const LogStyle.oneForAll(
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
        time = time ?? LogStyle.defaultStyle,
        path = path ?? LogStyle.defaultStyle,
        tags = tags ??
            const LogStyle.oneForAll(
              ansi.Style(foreground: _tagColor),
            ),
        controlCodes = controlCodes ?? LogStyle.defaultStyle,
        dataTitle = dataTitle ?? LogStyle.defaultStyle,
        dataName = dataName ?? LogStyle.defaultStyle,
        dataKey = dataKey ?? LogStyle.defaultStyle,
        dataIndex = dataIndex ?? LogStyle.defaultStyle,
        dataValue = dataValue ?? LogStyle.defaultStyle,
        dataUnits = dataUnits ?? LogStyle.defaultStyle,
        dataDim = dataDim ?? LogStyle.defaultStyle,
        dataLevel0 = dataLevel0 ?? LogStyle.defaultStyle,
        dataLevel1 = dataLevel1 ?? LogStyle.defaultStyle,
        dataLevel2 = dataLevel2 ?? LogStyle.defaultStyle,
        dataLevel3 = dataLevel3 ?? LogStyle.defaultStyle,
        dataLevelN = dataLevelN ?? LogStyle.defaultStyle,
        punctuation = punctuation ?? LogStyle.defaultStyle,
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
    required this.dataDim,
    required this.dataLevel0,
    required this.dataLevel1,
    required this.dataLevel2,
    required this.dataLevel3,
    required this.dataLevelN,
    required this.punctuation,
    required this.colon,
    required this.ellipsis,
    required this.lineBreak,
    required this.padding,
    required this.maxLength,
    required this.maxLines,
  });

  static const LogTheme noColorsTheme = LogTheme._raw(
    normal: LogStyle.defaultStyle,
    bold: LogStyle.defaultStyle,
    dim: LogStyle.defaultStyle,
    sequenceNum: LogStyle.defaultStyle,
    levelName: LogStyle.defaultStyle,
    time: LogStyle.defaultStyle,
    path: LogStyle.defaultStyle,
    tags: LogStyle.defaultStyle,
    controlCodes: LogStyle.defaultStyle,
    dataTitle: LogStyle.defaultStyle,
    dataName: LogStyle.defaultStyle,
    dataKey: LogStyle.defaultStyle,
    dataIndex: LogStyle.defaultStyle,
    dataValue: LogStyle.defaultStyle,
    dataUnits: LogStyle.defaultStyle,
    dataDim: LogStyle.defaultStyle,
    dataLevel0: LogStyle.defaultStyle,
    dataLevel1: LogStyle.defaultStyle,
    dataLevel2: LogStyle.defaultStyle,
    dataLevel3: LogStyle.defaultStyle,
    dataLevelN: LogStyle.defaultStyle,
    punctuation: LogStyle.defaultStyle,
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
  static const _normalInfoColor = ansi.Color256.rgb234;
  static const _normalWarningColor = ansi.Color256.rgb430;
  static const _normalErrorColor = ansi.Color256.rgb411;
  static const _normalCriticalColor = ansi.Color256.rgb414;

  static const _activeVerboseColor = ansi.Color256.gray10;
  static const _activeDebugColor = ansi.Color256.gray15;
  static const _activeInfoColor = ansi.Color256.rgb345;
  static const _activeWarningColor = ansi.Color256.rgb540;
  static const _activeErrorColor = ansi.Color256.rgb511;
  static const _activeCriticalColor = ansi.Color256.rgb515;

  static const _dimVerboseColor = ansi.Color256.gray5;
  static const _dimDebugColor = ansi.Color256.gray8;
  static const _dimInfoColor = ansi.Color256.rgb123;
  static const _dimWarningColor = ansi.Color256.rgb320;
  static const _dimErrorColor = ansi.Color256.rgb311;
  static const _dimCriticalColor = ansi.Color256.rgb313;

  // static const _superDimVerboseColor = ansi.Color256.gray5;
  // static const _superDimDebugColor = ansi.Color256.gray5;
  // static const _superDimInfoColor = ansi.Color256.rgb012;
  // static const _superDimWarningColor = ansi.Color256.rgb210;
  // static const _superDimErrorColor = ansi.Color256.rgb200;
  // static const _superDimCriticalColor = ansi.Color256.rgb202;

  // static const _punctuationColor = ansi.Color256.rgb045;
  static const _punctuationColor = ansi.Color256.rgb023;
  static const _tagColor = ansi.Color256.gray5;

  static const _normalDefaultStyle = LogStyle(
    verbose: ansi.Style(foreground: _normalVerboseColor),
    debug: ansi.Style(foreground: _normalDebugColor),
    info: ansi.Style(foreground: _normalInfoColor),
    warning: ansi.Style(foreground: _normalWarningColor),
    error: ansi.Style(foreground: _normalErrorColor),
    critical: ansi.Style(foreground: _normalCriticalColor),
  );
  static const _activeDefaultStyle = LogStyle(
    verbose: ansi.Style(foreground: _activeVerboseColor),
    debug: ansi.Style(foreground: _activeDebugColor),
    info: ansi.Style(foreground: _activeInfoColor),
    warning: ansi.Style(foreground: _activeWarningColor),
    error: ansi.Style(foreground: _activeErrorColor),
    critical: ansi.Style(foreground: _activeCriticalColor),
  );
  static const _boldDefaultStyle = LogStyle(
    verbose: ansi.Style(foreground: _activeVerboseColor, bold: true),
    debug: ansi.Style(foreground: _activeDebugColor, bold: true),
    info: ansi.Style(foreground: _activeInfoColor, bold: true),
    warning: ansi.Style(foreground: _activeWarningColor, bold: true),
    error: ansi.Style(foreground: _activeErrorColor, bold: true),
    critical: ansi.Style(foreground: _activeCriticalColor, bold: true),
  );
  static const _dimDefaultStyle = LogStyle(
    verbose: ansi.Style(foreground: _dimVerboseColor),
    debug: ansi.Style(foreground: _dimDebugColor),
    info: ansi.Style(foreground: _dimInfoColor),
    warning: ansi.Style(foreground: _dimWarningColor),
    error: ansi.Style(foreground: _dimErrorColor),
    critical: ansi.Style(foreground: _dimCriticalColor),
  );
  // static const _superDimDefaultStyle = LogStyle(
  //   verbose: ansi.Style(foreground: _superDimVerboseColor),
  //   debug: ansi.Style(foreground: _superDimDebugColor),
  //   info: ansi.Style(foreground: _superDimInfoColor),
  //   warning: ansi.Style(foreground: _superDimWarningColor),
  //   error: ansi.Style(foreground: _superDimErrorColor),
  //   critical: ansi.Style(foreground: _superDimCriticalColor),
  // );
  static const _tagDefaultStyle = LogStyle(
    verbose: ansi.Style(foreground: _tagColor),
    debug: ansi.Style(foreground: _tagColor),
    info: ansi.Style(foreground: _tagColor),
    warning: ansi.Style(foreground: _tagColor),
    error: ansi.Style(foreground: _tagColor),
    critical: ansi.Style(foreground: _tagColor),
  );

  static const LogTheme defaultTheme = LogTheme._raw(
    normal: _normalDefaultStyle,
    bold: _boldDefaultStyle,
    dim: _dimDefaultStyle,
    sequenceNum: _tagDefaultStyle,
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
    time: LogStyle.defaultStyle,
    path: _boldDefaultStyle,
    tags: _tagDefaultStyle,
    controlCodes: LogStyle.oneForAll(
      ansi.Style(foreground: _punctuationColor),
    ),
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
    dataName: LogStyle.defaultStyle,
    dataKey: _activeDefaultStyle,
    dataIndex: _dimDefaultStyle,
    dataValue: _normalDefaultStyle,
    dataUnits: _dimDefaultStyle,
    dataDim: _dimDefaultStyle,
    dataLevel0: LogStyle.oneForAll(
      ansi.Style(foreground: ansi.Color256.rgb045, bold: true),
    ),
    dataLevel1: LogStyle.oneForAll(
      ansi.Style(foreground: ansi.Color256.rgb034, bold: true),
    ),
    dataLevel2: LogStyle.oneForAll(
      ansi.Style(foreground: ansi.Color256.rgb023, bold: true),
    ),
    dataLevel3: LogStyle.oneForAll(
      ansi.Style(foreground: ansi.Color256.rgb012, bold: true),
    ),
    dataLevelN: _normalDefaultStyle,
    punctuation: LogStyle.oneForAll(
      ansi.Style(foreground: _punctuationColor),
    ),
    colon: LogPunctuation(
      ':',
      style: LogStyle.oneForAll(
        ansi.Style(foreground: _punctuationColor),
      ),
    ),
    ellipsis: LogPunctuation(
      '…',
      style: LogStyle.oneForAll(
        ansi.Style(foreground: _punctuationColor),
      ),
    ),
    lineBreak: LogPunctuation(
      '-',
      style: LogStyle.oneForAll(
        ansi.Style(foreground: _punctuationColor),
      ),
    ),
    padding: LogPunctuation(' '),
    maxLength: null,
    maxLines: null,
  );

  LogTheme copyWith({
    LogStyle? normal,
    LogStyle? bold,
    LogStyle? dim,
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
    LogStyle? dataDim,
    LogStyle? dataLevel0,
    LogStyle? dataLevel1,
    LogStyle? dataLevel2,
    LogStyle? dataLevel3,
    LogStyle? dataLevelN,
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
      dataDim: dataDim ?? this.dataDim,
      dataLevel0: dataLevel0 ?? this.dataLevel0,
      dataLevel1: dataLevel1 ?? this.dataLevel1,
      dataLevel2: dataLevel2 ?? this.dataLevel2,
      dataLevel3: dataLevel3 ?? this.dataLevel3,
      dataLevelN: dataLevelN ?? this.dataLevelN,
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
        dim: dataDim[level],
        level0: dataLevel0[level],
        level1: dataLevel1[level],
        level2: dataLevel2[level],
        level3: dataLevel3[level],
        levelN: dataLevelN[level],
        ellipsis: ellipsis.toAnsiStyled(level),
      );
}

final class LogPunctuation {
  final String _string;
  final LogStyle style;

  const LogPunctuation(
    this._string, {
    LogStyle? style,
  }) : style = style ?? LogStyle.defaultStyle;

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
}
