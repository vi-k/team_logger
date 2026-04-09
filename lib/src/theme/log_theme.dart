import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:team_logger/src/log_pre_formatters/control_code_log_pre_formatter.dart';

import '../log_formatters/extensions.dart';
import '../log_pre_formatters/bb_code_text_formatter.dart';
import '../log_pre_formatters/log_pre_formatter.dart';
import '../loggable/loggable.dart';
import '../logger/log_levels.dart';

part 'log_level_theme.dart';
part 'log_style.dart';

final class LogTheme with Loggable {
  final LogLevelTheme verbose;
  final LogLevelTheme debug;
  final LogLevelTheme info;
  final LogLevelTheme warning;
  final LogLevelTheme error;
  final LogLevelTheme critical;
  final int? maxLength;
  final int? maxLines;

  const LogTheme({
    this.verbose = LogLevelTheme.noColors,
    this.debug = LogLevelTheme.noColors,
    this.info = LogLevelTheme.noColors,
    this.warning = LogLevelTheme.noColors,
    this.error = LogLevelTheme.noColors,
    this.critical = LogLevelTheme.noColors,
    this.maxLength,
    this.maxLines,
  });

  LogLevelTheme operator [](int level) => switch (level) {
        LogLevels.verbose => verbose,
        LogLevels.debug => debug,
        LogLevels.info => info,
        LogLevels.warning => warning,
        LogLevels.error => error,
        LogLevels.critical => critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  static const LogTheme noColors = LogTheme();

  static const _black = ansi.Color256.gray0;

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

  static const _activeVerboseNormalColor = ansi.Color256.gray7;
  static const _activeVerboseNormalStyle =
      ansi.Style(foreground: _activeVerboseNormalColor);
  static const _activeDebugNormalColor = ansi.Color256.gray11;
  static const _activeDebugNormalStyle =
      ansi.Style(foreground: _activeDebugNormalColor);
  static const _activeInfoNormalColor = ansi.Color256.rgb233;
  static const _activeInfoNormalStyle =
      ansi.Style(foreground: _activeInfoNormalColor);
  static const _activeWarningNormalColor = ansi.Color256.rgb430;
  static const _activeWarningNormalStyle =
      ansi.Style(foreground: _activeWarningNormalColor);
  static const _activeErrorNormalColor = ansi.Color256.rgb411;
  static const _activeErrorNormalStyle =
      ansi.Style(foreground: _activeErrorNormalColor);
  static const _activeCriticalNormalColor = ansi.Color256.rgb414;
  static const _activeCriticalNormalStyle =
      ansi.Style(foreground: _activeCriticalNormalColor);

  static const _activeVerboseEmphasisColor = ansi.Color256.gray10;
  static const _activeVerboseEmphasisStyle =
      ansi.Style(foreground: _activeVerboseEmphasisColor);
  static const _activeVerboseBoldStyle =
      ansi.Style(foreground: _activeVerboseEmphasisColor, bold: true);
  static const _activeDebugEmphasisColor = ansi.Color256.gray15;
  static const _activeDebugEmphasisStyle =
      ansi.Style(foreground: _activeDebugEmphasisColor);
  static const _activeDebugBoldStyle =
      ansi.Style(foreground: _activeDebugEmphasisColor, bold: true);
  static const _activeInfoEmphasisColor = ansi.Color256.rgb344;
  static const _activeInfoEmphasisStyle =
      ansi.Style(foreground: _activeInfoEmphasisColor);
  static const _activeInfoBoldStyle =
      ansi.Style(foreground: _activeInfoEmphasisColor, bold: true);
  static const _activeWarningEmphasisColor = ansi.Color256.rgb540;
  static const _activeWarningEmphasisStyle =
      ansi.Style(foreground: _activeWarningEmphasisColor);
  static const _activeWarningBoldStyle =
      ansi.Style(foreground: _activeWarningEmphasisColor, bold: true);
  static const _activeErrorEmphasisColor = ansi.Color256.rgb511;
  static const _activeErrorEmphasisStyle =
      ansi.Style(foreground: _activeErrorEmphasisColor);
  static const _activeErrorBoldStyle =
      ansi.Style(foreground: _activeErrorEmphasisColor, bold: true);
  static const _activeCriticalEmphasisColor = ansi.Color256.rgb515;
  static const _activeCriticalEmphasisStyle =
      ansi.Style(foreground: _activeCriticalEmphasisColor);
  static const _activeCriticalBoldStyle =
      ansi.Style(foreground: _activeCriticalEmphasisColor, bold: true);

  static const _activeVerboseDimColor = ansi.Color256.gray5;
  static const _activeDebugDimColor = ansi.Color256.gray8;
  static const _activeInfoDimColor = ansi.Color256.rgb122;
  static const _activeWarningDimColor = ansi.Color256.rgb320;
  static const _activeErrorDimColor = ansi.Color256.rgb311;
  static const _activeCriticalDimColor = ansi.Color256.rgb313;

  static const _activeVerboseSuperDimColor = ansi.Color256.gray4;
  static const _activeDebugSuperDimColor = ansi.Color256.gray4;
  static const _activeInfoSuperDimColor = ansi.Color256.rgb011;
  static const _activeWarningSuperDimColor = ansi.Color256.rgb210;
  static const _activeErrorSuperDimColor = ansi.Color256.rgb200;
  static const _activeCriticalSuperDimColor = ansi.Color256.rgb202;

  static const _activeVerbosePunctuationColor = ansi.Color256.rgb023;
  static const _activeDebugPunctuationColor = ansi.Color256.rgb034;
  static const _activePunctuationColor = ansi.Color256.rgb045;

  static const _activeVerboseLevels0Color = ansi.Color256.rgb310;
  static const _activeVerboseLevels1Color = ansi.Color256.rgb130;
  static const _activeVerboseLevels2Color = ansi.Color256.rgb023;
  static const _activeVerboseLevels3Color = ansi.Color256.rgb213;

  static const _activeDebugLevels0Color = ansi.Color256.rgb420;
  static const _activeDebugLevels1Color = ansi.Color256.rgb240;
  static const _activeDebugLevels2Color = ansi.Color256.rgb034;
  static const _activeDebugLevels3Color = ansi.Color256.rgb324;

  static const _activeDebugLevels0DimColor = ansi.Color256.rgb310;
  static const _activeDebugLevels1DimColor = ansi.Color256.rgb130;
  static const _activeDebugLevels2DimColor = ansi.Color256.rgb023;
  static const _activeDebugLevels3DimColor = ansi.Color256.rgb213;

  static const _activeLevels0Color = ansi.Color256.rgb530;
  static const _activeLevels1Color = ansi.Color256.rgb350;
  static const _activeLevels2Color = ansi.Color256.rgb045;
  static const _activeLevels3Color = ansi.Color256.rgb425;

  static const _activeLevels0DimColor = ansi.Color256.rgb420;
  static const _activeLevels1DimColor = ansi.Color256.rgb240;
  static const _activeLevels2DimColor = ansi.Color256.rgb034;
  static const _activeLevels3DimColor = ansi.Color256.rgb324;

  static const _tagsColor = ansi.Color256.gray5;

  static const LogTheme defaultActiveTheme = LogTheme(
    verbose: LogLevelTheme._(
      normalStyle: _activeVerboseNormalStyle,
      boldStyle: _activeVerboseBoldStyle,
      dimStyle: ansi.Style(foreground: _activeVerboseDimColor),
      superDimStyle: ansi.Style(foreground: _activeVerboseSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeVerboseNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeVerboseBoldStyle,
      messageStyles: {
        'b': _activeVerboseBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      colonStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      paddingStyle: ansi.Style(foreground: _activeVerbosePunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeVerboseDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeVerboseEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeVerboseDimColor),
      dataBracketsStyles: [
        ansi.Style(foreground: _activeVerboseLevels0Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels1Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels2Color, bold: true),
        ansi.Style(foreground: _activeVerboseLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeDebugLevels0DimColor),
        ansi.Style(foreground: _activeDebugLevels1DimColor),
        ansi.Style(foreground: _activeDebugLevels2DimColor),
        ansi.Style(foreground: _activeDebugLevels3DimColor),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeVerboseLevels0Color),
        ansi.Style(foreground: _activeVerboseLevels1Color),
        ansi.Style(foreground: _activeVerboseLevels2Color),
        ansi.Style(foreground: _activeVerboseLevels3Color),
      ],
      showCount: true,
      showIndexes: true,
    ),
    debug: LogLevelTheme._(
      normalStyle: _activeDebugNormalStyle,
      boldStyle: _activeDebugBoldStyle,
      dimStyle: ansi.Style(foreground: _activeDebugDimColor),
      superDimStyle: ansi.Style(foreground: _activeDebugSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeDebugNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeDebugBoldStyle,
      messageStyles: {
        'b': _activeDebugBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      colonStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      paddingStyle: ansi.Style(foreground: _activeDebugPunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeDebugDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeDebugEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeDebugDimColor),
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
      showCount: true,
      showIndexes: true,
    ),
    info: LogLevelTheme._(
      normalStyle: _activeInfoNormalStyle,
      boldStyle: _activeInfoBoldStyle,
      dimStyle: ansi.Style(foreground: _activeInfoDimColor),
      superDimStyle: ansi.Style(foreground: _activeInfoSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeInfoNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeInfoBoldStyle,
      messageStyles: {
        'b': _activeInfoBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activePunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activePunctuationColor),
      colonStyle: ansi.Style(foreground: _activePunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activePunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activePunctuationColor),
      paddingStyle: ansi.Style(foreground: _activePunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeInfoDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeInfoEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeInfoDimColor),
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
      showCount: true,
      showIndexes: true,
    ),
    warning: LogLevelTheme._(
      normalStyle: _activeWarningNormalStyle,
      boldStyle: _activeWarningBoldStyle,
      dimStyle: ansi.Style(foreground: _activeWarningDimColor),
      superDimStyle: ansi.Style(foreground: _activeWarningSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeWarningNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeWarningBoldStyle,
      messageStyles: {
        'b': _activeWarningBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activePunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activePunctuationColor),
      colonStyle: ansi.Style(foreground: _activePunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activePunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activePunctuationColor),
      paddingStyle: ansi.Style(foreground: _activePunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeWarningDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeWarningEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeWarningDimColor),
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      showCount: true,
      showIndexes: true,
    ),
    error: LogLevelTheme._(
      normalStyle: _activeErrorNormalStyle,
      boldStyle: _activeErrorBoldStyle,
      dimStyle: ansi.Style(foreground: _activeErrorDimColor),
      superDimStyle: ansi.Style(foreground: _activeErrorSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeErrorNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeErrorBoldStyle,
      messageStyles: {
        'b': _activeErrorBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activePunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activePunctuationColor),
      colonStyle: ansi.Style(foreground: _activePunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activePunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activePunctuationColor),
      paddingStyle: ansi.Style(foreground: _activePunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeErrorDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeErrorEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeErrorDimColor),
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      showCount: true,
      showIndexes: true,
    ),
    critical: LogLevelTheme._(
      normalStyle: _activeCriticalNormalStyle,
      boldStyle: _activeCriticalBoldStyle,
      dimStyle: ansi.Style(foreground: _activeCriticalDimColor),
      superDimStyle: ansi.Style(foreground: _activeCriticalSuperDimColor),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.Style(
        foreground: _black,
        background: _activeCriticalNormalColor,
      ),
      timeStyle: ansi.NoStyle(),
      pathStyle: _activeCriticalBoldStyle,
      messageStyles: {
        'b': _activeCriticalBoldStyle,
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _activeErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
      controlCodesStyle: ansi.Style(foreground: _activePunctuationColor),
      punctuationStyle: ansi.Style(foreground: _activePunctuationColor),
      colonStyle: ansi.Style(foreground: _activePunctuationColor),
      ellipsisStyle: ansi.Style(foreground: _activePunctuationColor),
      lineBreakStyle: ansi.Style(foreground: _activePunctuationColor),
      paddingStyle: ansi.Style(foreground: _activePunctuationColor),
      dataSectionStyle: ansi.Style(
        foreground: _black,
        background: _activeCriticalDimColor,
      ),
      dataNameStyle: ansi.NoStyle(),
      dataKeyStyle: _activeCriticalEmphasisStyle,
      dataValueStyle: ansi.NoStyle(),
      dataUnitsStyle: ansi.Style(foreground: _activeCriticalDimColor),
      dataBracketsStyles: [
        ansi.Style(foreground: _activeLevels0Color, bold: true),
        ansi.Style(foreground: _activeLevels1Color, bold: true),
        ansi.Style(foreground: _activeLevels2Color, bold: true),
        ansi.Style(foreground: _activeLevels3Color, bold: true),
      ],
      dataDescriptionStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      dataPunctuationStyles: [
        ansi.Style(foreground: _activeLevels0Color),
        ansi.Style(foreground: _activeLevels1Color),
        ansi.Style(foreground: _activeLevels2Color),
        ansi.Style(foreground: _activeLevels3Color),
      ],
      showCount: true,
      showIndexes: true,
    ),
  );

  static const LogTheme defaultInactiveTheme = LogTheme(
    verbose: LogLevelTheme._(
      normalStyle: _inactiveVerboseNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
    debug: LogLevelTheme._(
      normalStyle: _inactiveDebugNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
    info: LogLevelTheme._(
      normalStyle: _inactiveInfoNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
    warning: LogLevelTheme._(
      normalStyle: _inactiveWarningNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
    error: LogLevelTheme._(
      normalStyle: _inactiveErrorNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
    critical: LogLevelTheme._(
      normalStyle: _inactiveCriticalNormalStyle,
      boldStyle: ansi.NoStyle(),
      dimStyle: ansi.NoStyle(),
      superDimStyle: ansi.NoStyle(),
      sequenceNumStyle: ansi.Style(foreground: _tagsColor),
      levelNameStyle: ansi.NoStyle(),
      timeStyle: ansi.NoStyle(),
      pathStyle: ansi.NoStyle(),
      messageStyles: {
        'b': ansi.Style(bold: true),
        // 'ok': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.rgb050),
        // ),
        // 'trace': const BbCodeFormat.colorize(
        //   LogStyle.only(ansi.magenta),
        // ),
        // 'signal': const BbCodeFormat.colorize(
        //   LogStyle.only(
        //     ansi.Style(
        //       foreground: ansi.Color256.rgb055,
        //       background: ansi.Color256.rgb011,
        //     ),
        //   ),
        // ),
        'error': _inactiveErrorNormalStyle,
      },
      valueFormatter: ControlCodeLogPreFormatter(),
      messageFormatter: BbCodeLogPreFormatter(),
      tagsStyle: ansi.Style(foreground: _tagsColor),
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
      showCount: true,
      showIndexes: true,
    ),
  );

  LogTheme copyWith({
    LogLevelTheme? verbose,
    LogLevelTheme? debug,
    LogLevelTheme? info,
    LogLevelTheme? warning,
    LogLevelTheme? error,
    LogLevelTheme? critical,
    int? maxLength,
    int? maxLines,
  }) =>
      LogTheme(
        verbose: verbose ?? this.verbose,
        debug: debug ?? this.debug,
        info: info ?? this.info,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        critical: critical ?? this.critical,
        maxLength: maxLength ?? this.maxLength,
        maxLines: maxLines ?? this.maxLines,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('verbose', verbose)
      ..prop('debug', debug)
      ..prop('info', info)
      ..prop('warning', warning)
      ..prop('error', error)
      ..prop('critical', critical)
      ..prop('maxLength', maxLength)
      ..prop('maxLines', maxLines);
  }
}
