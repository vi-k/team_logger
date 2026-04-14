import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;

import '../log_preformatters/bb_code_formatter.dart';
import '../log_preformatters/control_code_formatter.dart';
import '../log_preformatters/log_pre_formatter.dart';
import '../loggable/loggable.dart';
import '../logger/log.dart';
import '../logger/log_levels.dart';
import '../printer/extensions.dart';

part 'log_level_theme.dart';
part 'log_style.dart';

typedef LogThemeFormatter<T extends Object?> = String Function(
  LogLevelTheme theme,
  T,
);

final class LogTheme with Loggable {
  static const String defaultColon = ':';
  static const String defaultEllipsis = '…';
  static const String defaultLineBreak = '-';
  static const String defaultPadding = ' ';
  static const String defaulDataSectionName = 'DATA';

  final LogLevelTheme verbose;
  final LogLevelTheme debug;
  final LogLevelTheme info;
  final LogLevelTheme warning;
  final LogLevelTheme error;
  final LogLevelTheme critical;
  final ansi.Style hiddenStyle;
  final String colon;
  final String ellipsis;
  final String lineBreak;
  final String padding;
  final bool errorOnNewLine;
  final bool dataOnNewLine;
  final String dataSectionName;
  final bool showCount;
  final bool showIndexes;
  final LogThemeFormatter<String> sectionNameFormatter;
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
    this.hiddenStyle = _hiddenStyle,
    this.colon = defaultColon,
    this.ellipsis = defaultEllipsis,
    this.lineBreak = defaultLineBreak,
    this.padding = defaultPadding,
    this.errorOnNewLine = false,
    this.dataOnNewLine = true,
    this.dataSectionName = defaulDataSectionName,
    this.showCount = true,
    this.showIndexes = true,
    this.sectionNameFormatter = _defaultSectionNameFormatter,
    this.countFormatter = _defaultCountFormatter,
    this.indexFormatter = _defaultIndexFormatter,
    this.tags = const {},
  })  : assert(!colon.ansiHasEscapeCodes),
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
    this.hiddenStyle = const ansi.NoStyle(),
  })  : colon = defaultColon,
        ellipsis = defaultEllipsis,
        lineBreak = defaultLineBreak,
        padding = defaultPadding,
        errorOnNewLine = false,
        dataOnNewLine = true,
        dataSectionName = defaulDataSectionName,
        showCount = true,
        showIndexes = true,
        sectionNameFormatter = _defaultSectionNameFormatter,
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

  static const _black = ansi.Color256.gray0;

  static const _tagsStyle = ansi.Style(foreground: ansi.Color256.gray5);

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

  // active verbose

  static const _activeVerboseNormalColor = ansi.Color256.gray7;
  static const _activeVerboseEmphasisColor = ansi.Color256.gray10;
  static const _activeVerboseDimColor = ansi.Color256.gray5;
  static const _activeVerboseSuperDimColor = ansi.Color256.gray4;
  static const _activeVerbosePunctuationColor = ansi.Color256.rgb023;
  static const _activeVerboseLevels0Color = ansi.Color256.rgb310;
  static const _activeVerboseLevels1Color = ansi.Color256.rgb130;
  static const _activeVerboseLevels2Color = ansi.Color256.rgb023;
  static const _activeVerboseLevels3Color = ansi.Color256.rgb213;
  static const _activeVerboseLevels0DimColor = _activeDebugLevels0DimColor;
  static const _activeVerboseLevels1DimColor = _activeDebugLevels1DimColor;
  static const _activeVerboseLevels2DimColor = _activeDebugLevels2DimColor;
  static const _activeVerboseLevels3DimColor = _activeDebugLevels3DimColor;

  static const _activeVerboseNormalStyle =
      ansi.Style(foreground: _activeVerboseNormalColor);
  static const _activeVerboseEmphasisStyle =
      ansi.Style(foreground: _activeVerboseEmphasisColor);
  static const _activeVerboseBoldStyle =
      ansi.Style(foreground: _activeVerboseEmphasisColor, bold: true);
  static const _activeVerboseDimStyle =
      ansi.Style(foreground: _activeVerboseDimColor);
  static const _activeVerboseSuperDimStyle =
      ansi.Style(foreground: _activeVerboseSuperDimColor);
  static const _activeVerbosePunctuationStyle =
      ansi.Style(foreground: _activeVerbosePunctuationColor);

  // active debug

  static const _activeDebugNormalColor = ansi.Color256.gray11;
  static const _activeDebugEmphasisColor = ansi.Color256.gray15;
  static const _activeDebugDimColor = ansi.Color256.gray8;
  static const _activeDebugSuperDimColor = ansi.Color256.gray4;
  static const _activeDebugPunctuationColor = ansi.Color256.rgb034;
  static const _activeDebugLevels0Color = ansi.Color256.rgb420;
  static const _activeDebugLevels1Color = ansi.Color256.rgb240;
  static const _activeDebugLevels2Color = ansi.Color256.rgb034;
  static const _activeDebugLevels3Color = ansi.Color256.rgb324;
  static const _activeDebugLevels0DimColor = ansi.Color256.rgb310;
  static const _activeDebugLevels1DimColor = ansi.Color256.rgb130;
  static const _activeDebugLevels2DimColor = ansi.Color256.rgb023;
  static const _activeDebugLevels3DimColor = ansi.Color256.rgb213;

  static const _activeDebugNormalStyle =
      ansi.Style(foreground: _activeDebugNormalColor);
  static const _activeDebugEmphasisStyle =
      ansi.Style(foreground: _activeDebugEmphasisColor);
  static const _activeDebugBoldStyle =
      ansi.Style(foreground: _activeDebugEmphasisColor, bold: true);
  static const _activeDebugDimStyle =
      ansi.Style(foreground: _activeDebugDimColor);
  static const _activeDebugSuperDimStyle =
      ansi.Style(foreground: _activeDebugSuperDimColor);
  static const _activeDebugPunctuationStyle =
      ansi.Style(foreground: _activeDebugPunctuationColor);

  // active info

  static const _activeInfoNormalColor = ansi.Color256.rgb234;
  static const _activeInfoEmphasisColor = ansi.Color256.rgb345;
  static const _activeInfoDimColor = ansi.Color256.rgb123;
  static const _activeInfoSuperDimColor = ansi.Color256.rgb012;
  // static const _activeInfoNormalColor = ansi.Color256.rgb233;
  // static const _activeInfoEmphasisColor = ansi.Color256.rgb344;
  // static const _activeInfoDimColor = ansi.Color256.rgb122;
  // static const _activeInfoSuperDimColor = ansi.Color256.rgb011;

  static const _activeInfoNormalStyle =
      ansi.Style(foreground: _activeInfoNormalColor);
  static const _activeInfoEmphasisStyle =
      ansi.Style(foreground: _activeInfoEmphasisColor);
  static const _activeInfoBoldStyle =
      ansi.Style(foreground: _activeInfoEmphasisColor, bold: true);
  static const _activeInfoDimStyle =
      ansi.Style(foreground: _activeInfoDimColor);
  static const _activeInfoSuperDimStyle =
      ansi.Style(foreground: _activeInfoSuperDimColor);
  static const _activeInfoPunctuationStyle =
      ansi.Style(foreground: _activePunctuationColor);

  // active warning

  static const _activeWarningNormalColor = ansi.Color256.rgb430;
  static const _activeWarningEmphasisColor = ansi.Color256.rgb540;
  static const _activeWarningDimColor = ansi.Color256.rgb320;
  static const _activeWarningSuperDimColor = ansi.Color256.rgb210;

  static const _activeWarningNormalStyle =
      ansi.Style(foreground: _activeWarningNormalColor);
  static const _activeWarningEmphasisStyle =
      ansi.Style(foreground: _activeWarningEmphasisColor);
  static const _activeWarningBoldStyle =
      ansi.Style(foreground: _activeWarningEmphasisColor, bold: true);
  static const _activeWarningDimStyle =
      ansi.Style(foreground: _activeWarningDimColor);
  static const _activeWarningSuperDimStyle =
      ansi.Style(foreground: _activeWarningSuperDimColor);
  static const _activeWarningPunctuationStyle =
      ansi.Style(foreground: _activePunctuationColor);

  // active error

  static const _activeErrorNormalColor = ansi.Color256.rgb411;
  static const _activeErrorEmphasisColor = ansi.Color256.rgb511;
  static const _activeErrorDimColor = ansi.Color256.rgb311;
  static const _activeErrorSuperDimColor = ansi.Color256.rgb200;

  static const _activeErrorNormalStyle =
      ansi.Style(foreground: _activeErrorNormalColor);
  static const _activeErrorEmphasisStyle =
      ansi.Style(foreground: _activeErrorEmphasisColor);
  static const _activeErrorBoldStyle =
      ansi.Style(foreground: _activeErrorEmphasisColor, bold: true);
  static const _activeErrorDimStyle =
      ansi.Style(foreground: _activeErrorDimColor);
  static const _activeErrorSuperDimStyle =
      ansi.Style(foreground: _activeErrorSuperDimColor);
  static const _activeErrorPunctuationStyle =
      ansi.Style(foreground: _activePunctuationColor);

  // active critical

  static const _activeCriticalNormalColor = ansi.Color256.rgb414;
  static const _activeCriticalEmphasisColor = ansi.Color256.rgb515;
  static const _activeCriticalDimColor = ansi.Color256.rgb313;
  static const _activeCriticalSuperDimColor = ansi.Color256.rgb202;

  static const _activeCriticalNormalStyle =
      ansi.Style(foreground: _activeCriticalNormalColor);
  static const _activeCriticalEmphasisStyle =
      ansi.Style(foreground: _activeCriticalEmphasisColor);
  static const _activeCriticalBoldStyle =
      ansi.Style(foreground: _activeCriticalEmphasisColor, bold: true);
  static const _activeCriticalDimStyle =
      ansi.Style(foreground: _activeCriticalDimColor);
  static const _activeCriticalSuperDimStyle =
      ansi.Style(foreground: _activeCriticalSuperDimColor);
  static const _activeCriticalPunctuationStyle =
      ansi.Style(foreground: _activePunctuationColor);

  // active common

  static const _activePunctuationColor = ansi.Color256.rgb045;

  static const _activeLevels0Color = ansi.Color256.rgb530;
  static const _activeLevels0DimColor = ansi.Color256.rgb420;
  static const _activeLevels1Color = ansi.Color256.rgb350;
  static const _activeLevels1DimColor = ansi.Color256.rgb240;
  static const _activeLevels2Color = ansi.Color256.rgb045;
  static const _activeLevels2DimColor = ansi.Color256.rgb034;
  static const _activeLevels3Color = ansi.Color256.rgb425;
  static const _activeLevels3DimColor = ansi.Color256.rgb324;

  static const LogTheme defaultActiveTheme = LogTheme._(
    verbose: LogLevelTheme._(
      normalStyle: _activeVerboseNormalStyle,
      boldStyle: _activeVerboseBoldStyle,
      dimStyle: _activeVerboseDimStyle,
      superDimStyle: _activeVerboseSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeVerboseNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeVerboseEmphasisStyle,
      messageStyles: {
        'b': _activeVerboseBoldStyle,
        'success': ansi.rgb030,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeVerbosePunctuationStyle,
      punctuationStyle: _activeVerbosePunctuationStyle,
      colonStyle: _activeVerbosePunctuationStyle,
      ellipsisStyle: _activeVerbosePunctuationStyle,
      lineBreakStyle: _activeVerbosePunctuationStyle,
      paddingStyle: _activeVerbosePunctuationStyle,
      dataSectionStyle: _activeVerboseBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeVerboseEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeVerboseDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeVerboseLevels0Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels1Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels2Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeVerboseLevels0DimColor),
        ansi.Style(foreground: _activeVerboseLevels1DimColor),
        ansi.Style(foreground: _activeVerboseLevels2DimColor),
        ansi.Style(foreground: _activeVerboseLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeVerboseLevels0Color),
        ansi.Style(foreground: _activeVerboseLevels1Color),
        ansi.Style(foreground: _activeVerboseLevels2Color),
        ansi.Style(foreground: _activeVerboseLevels3Color),
      ],
    ),
    debug: LogLevelTheme._(
      normalStyle: _activeDebugNormalStyle,
      boldStyle: _activeDebugBoldStyle,
      dimStyle: _activeDebugDimStyle,
      superDimStyle: _activeDebugSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeDebugNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeDebugEmphasisStyle,
      messageStyles: {
        'b': _activeDebugBoldStyle,
        'success': ansi.rgb040,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeDebugPunctuationStyle,
      punctuationStyle: _activeDebugPunctuationStyle,
      colonStyle: _activeDebugPunctuationStyle,
      ellipsisStyle: _activeDebugPunctuationStyle,
      lineBreakStyle: _activeDebugPunctuationStyle,
      paddingStyle: _activeDebugPunctuationStyle,
      dataSectionStyle: _activeDebugBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeDebugEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeDebugDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeDebugLevels0Color, bold: true),
        ansi.Style(foreground: _activeDebugLevels1Color, bold: true),
        ansi.Style(foreground: _activeDebugLevels2Color, bold: true),
        ansi.Style(foreground: _activeDebugLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeDebugLevels0DimColor),
        ansi.Style(foreground: _activeDebugLevels1DimColor),
        ansi.Style(foreground: _activeDebugLevels2DimColor),
        ansi.Style(foreground: _activeDebugLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeDebugLevels0Color),
        ansi.Style(foreground: _activeDebugLevels1Color),
        ansi.Style(foreground: _activeDebugLevels2Color),
        ansi.Style(foreground: _activeDebugLevels3Color),
      ],
    ),
    info: LogLevelTheme._(
      normalStyle: _activeInfoNormalStyle,
      boldStyle: _activeInfoBoldStyle,
      dimStyle: _activeInfoDimStyle,
      superDimStyle: _activeInfoSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeInfoNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeInfoEmphasisStyle,
      messageStyles: {
        'b': _activeInfoBoldStyle,
        'success': ansi.rgb050,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeInfoPunctuationStyle,
      punctuationStyle: _activeInfoPunctuationStyle,
      colonStyle: _activeInfoPunctuationStyle,
      ellipsisStyle: _activeInfoPunctuationStyle,
      lineBreakStyle: _activeInfoPunctuationStyle,
      paddingStyle: _activeInfoPunctuationStyle,
      dataSectionStyle: _activeInfoBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeInfoEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeInfoDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0DimColor),
        ansi.Style(foreground: _activeLevels1DimColor),
        ansi.Style(foreground: _activeLevels2DimColor),
        ansi.Style(foreground: _activeLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
    ),
    warning: LogLevelTheme._(
      normalStyle: _activeWarningNormalStyle,
      boldStyle: _activeWarningBoldStyle,
      dimStyle: _activeWarningDimStyle,
      superDimStyle: _activeWarningSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeWarningNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeWarningEmphasisStyle,
      messageStyles: {
        'b': _activeWarningBoldStyle,
        'success': ansi.rgb050,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeWarningPunctuationStyle,
      punctuationStyle: _activeWarningPunctuationStyle,
      colonStyle: _activeWarningPunctuationStyle,
      ellipsisStyle: _activeWarningPunctuationStyle,
      lineBreakStyle: _activeWarningPunctuationStyle,
      paddingStyle: _activeWarningPunctuationStyle,
      dataSectionStyle: _activeWarningBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeWarningEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeWarningDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0DimColor),
        ansi.Style(foreground: _activeLevels1DimColor),
        ansi.Style(foreground: _activeLevels2DimColor),
        ansi.Style(foreground: _activeLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
    ),
    error: LogLevelTheme._(
      normalStyle: _activeErrorNormalStyle,
      boldStyle: _activeErrorBoldStyle,
      dimStyle: _activeErrorDimStyle,
      superDimStyle: _activeErrorSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeErrorNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeErrorEmphasisStyle,
      messageStyles: {
        'b': _activeErrorBoldStyle,
        'success': ansi.rgb050,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeErrorPunctuationStyle,
      punctuationStyle: _activeErrorPunctuationStyle,
      colonStyle: _activeErrorPunctuationStyle,
      ellipsisStyle: _activeErrorPunctuationStyle,
      lineBreakStyle: _activeErrorPunctuationStyle,
      paddingStyle: _activeErrorPunctuationStyle,
      dataSectionStyle: _activeErrorBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeErrorEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeErrorDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0DimColor),
        ansi.Style(foreground: _activeLevels1DimColor),
        ansi.Style(foreground: _activeLevels2DimColor),
        ansi.Style(foreground: _activeLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
    ),
    critical: LogLevelTheme._(
      normalStyle: _activeCriticalNormalStyle,
      boldStyle: _activeCriticalBoldStyle,
      dimStyle: _activeCriticalDimStyle,
      superDimStyle: _activeCriticalSuperDimStyle,
      sequenceNumStyle: ansi.NoStyle(),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeCriticalNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeCriticalEmphasisStyle,
      messageStyles: {
        'b': _activeCriticalBoldStyle,
        'success': ansi.rgb050,
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeFormatter(),
      messageFormatter: BbCodeFormatter(),
      tagsStyle: _tagsStyle,
      controlCodesStyle: _activeCriticalPunctuationStyle,
      punctuationStyle: _activeCriticalPunctuationStyle,
      colonStyle: _activeCriticalPunctuationStyle,
      ellipsisStyle: _activeCriticalPunctuationStyle,
      lineBreakStyle: _activeCriticalPunctuationStyle,
      paddingStyle: _activeCriticalPunctuationStyle,
      dataSectionStyle: _activeCriticalBoldStyle,
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeCriticalEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: _activeCriticalDimStyle,
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0DimColor),
        ansi.Style(foreground: _activeLevels1DimColor),
        ansi.Style(foreground: _activeLevels2DimColor),
        ansi.Style(foreground: _activeLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
    ),
    hiddenStyle: _hiddenStyle,
  );

  static const LogTheme defaultInactiveTheme = LogTheme._(
    verbose: LogLevelTheme._(
      normalStyle: _inactiveVerboseNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    debug: LogLevelTheme._(
      normalStyle: _inactiveDebugNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    info: LogLevelTheme._(
      normalStyle: _inactiveInfoNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    warning: LogLevelTheme._(
      normalStyle: _inactiveWarningNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    error: LogLevelTheme._(
      normalStyle: _inactiveErrorNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    critical: LogLevelTheme._(
      normalStyle: _inactiveCriticalNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
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
      tagsStyle: ansi.NoStyle(),
      controlCodesStyle: ansi.NoStyle(),
      punctuationStyle: ansi.NoStyle(),
      colonStyle: ansi.NoStyle(),
      ellipsisStyle: ansi.NoStyle(),
      lineBreakStyle: ansi.NoStyle(),
      paddingStyle: ansi.NoStyle(),
      dataSectionStyle: ansi.NoStyle(),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: ansi.NoStyle(),
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.NoStyle(),
      dataBracketsStyles: [ansi.NoStyle()],
      dataDescriptionStyles: [ansi.NoStyle()],
      dataPunctuationStyles: [ansi.NoStyle()],
    ),
    hiddenStyle: _hiddenStyle,
  );

  static String _defaultSectionNameFormatter(
    LogLevelTheme theme,
    String name,
  ) =>
      '$name${theme.common.colon}';

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
    ansi.Style? hiddenStyle,
    String? colon,
    String? ellipsis,
    String? lineBreak,
    String? padding,
    bool? errorOnNewLine,
    bool? dataOnNewLine,
    String? dataSectionName,
    bool? showCount,
    bool? showIndexes,
    LogThemeFormatter<String>? sectionNameFormatter,
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
        hiddenStyle: hiddenStyle ?? this.hiddenStyle,
        colon: colon ?? this.colon,
        ellipsis: ellipsis ?? this.ellipsis,
        lineBreak: lineBreak ?? this.lineBreak,
        padding: padding ?? this.padding,
        errorOnNewLine: errorOnNewLine ?? this.errorOnNewLine,
        dataOnNewLine: dataOnNewLine ?? this.dataOnNewLine,
        dataSectionName: dataSectionName ?? this.dataSectionName,
        showCount: showCount ?? this.showCount,
        showIndexes: showIndexes ?? this.showIndexes,
        sectionNameFormatter: sectionNameFormatter ?? this.sectionNameFormatter,
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
        view: verbose.normalStyle('verbose'),
      )
      ..prop(
        'debug',
        debug,
        showName: false,
        view: debug.normalStyle('debug'),
      )
      ..prop(
        'info',
        info,
        showName: false,
        view: info.normalStyle('info'),
      )
      ..prop(
        'warning',
        warning,
        showName: false,
        view: warning.normalStyle('warning'),
      )
      ..prop(
        'error',
        error,
        showName: false,
        view: error.normalStyle('error'),
      )
      ..prop(
        'critical',
        critical,
        showName: false,
        view: critical.normalStyle('critical'),
      )
      ..style('hiddenStyle', hiddenStyle, showName: true)
      ..prop('colon', colon)
      ..prop('ellipsis', ellipsis)
      ..prop('lineBreak', lineBreak)
      ..prop('padding', padding)
      ..prop('errorOnNewLine', errorOnNewLine)
      ..prop('dataOnNewLine', dataOnNewLine)
      ..prop('dataSectionName', dataSectionName)
      ..prop('showCount', showCount)
      ..prop('showIndexes', showIndexes)
      ..prop('tags', tags);
  }
}
