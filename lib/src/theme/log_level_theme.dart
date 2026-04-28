part of 'log_theme.dart';

final class LogLevelTheme with Loggable {
  static final _mainThemeExpando = Expando<LogTheme>();

  final ansi.Style normal;
  final ansi.Style inverse;
  final ansi.Style bold;
  final ansi.Style emphasis;
  final ansi.Style dim;
  final ansi.Style punctuation;
  final ansi.Style sequenceNumStyle;
  final ansi.Style levelNameStyle;
  final ansi.Style timeStyle;
  final ansi.Style pathStyle;
  final Map<String, ansi.Style> messageStyles;
  final LogPreFormatter valueFormatter;
  final LogPreFormatter messageFormatter;
  final ansi.Style controlCodesStyle;
  final ansi.Style colonStyle;
  final ansi.Style ellipsisStyle;
  final ansi.Style lineBreakStyle;
  final ansi.Style paddingStyle;
  final ansi.Style sectionStyle;
  final ansi.Style dataNameStyle;
  final ansi.Style dataKeyStyle;
  final ansi.Style dataValueStyle;
  final ansi.Style dataUnitsStyle;
  final List<LogDataBlockTheme> dataBlockTheme;
  final ansi.Style stackTraceActiveStyle;
  final ansi.Style stackTraceInactiveStyle;
  final Set<String> tags;

  const LogLevelTheme({
    required this.normal,
    required this.inverse,
    required this.bold,
    required this.emphasis,
    required this.dim,
    required this.punctuation,
    required this.sequenceNumStyle,
    required this.levelNameStyle,
    required this.timeStyle,
    required this.pathStyle,
    required this.messageStyles,
    required this.valueFormatter,
    required this.messageFormatter,
    required this.controlCodesStyle,
    required this.colonStyle,
    required this.ellipsisStyle,
    required this.lineBreakStyle,
    required this.paddingStyle,
    required this.sectionStyle,
    required this.dataNameStyle,
    required this.dataKeyStyle,
    required this.dataValueStyle,
    required this.dataUnitsStyle,
    required this.dataBlockTheme,
    required this.stackTraceActiveStyle,
    required this.stackTraceInactiveStyle,
    this.tags = const {},
  });

  LogLevelTheme.seed({
    required this.normal,
    ansi.Style? inverse,
    ansi.Style? bold,
    required this.emphasis,
    required this.dim,
    required this.punctuation,
    this.sequenceNumStyle = const ansi.NoStyle(),
    ansi.Style? levelNameStyle,
    this.timeStyle = const ansi.NoStyle(),
    ansi.Style? pathStyle,
    required Map<String, ansi.Style> messageStyles,
    this.valueFormatter = const ControlCodeFormatter(),
    this.messageFormatter = const BbCodeFormatter(),
    ansi.Style? controlCodesStyle,
    ansi.Style? colonStyle,
    ansi.Style? ellipsisStyle,
    ansi.Style? lineBreakStyle,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    this.dataNameStyle = const ansi.NoStyle(),
    ansi.Style? dataKeyStyle,
    this.dataValueStyle = const ansi.NoStyle(),
    ansi.Style? dataUnitsStyle,
    required this.dataBlockTheme,
    ansi.Style? stackTraceActiveStyle,
    ansi.Style? stackTraceInactiveStyle,
    this.tags = const {},
  })  : bold = bold ?? emphasis.bold,
        inverse = inverse ??
            ansi.Style(
              foreground: _black,
              background: normal.foregroundColor,
            ),
        levelNameStyle = levelNameStyle ??
            inverse ??
            ansi.Style(
              foreground: _black,
              background: normal.foregroundColor,
            ),
        pathStyle = pathStyle ?? emphasis,
        messageStyles = Map.of(messageStyles)..['b'] = emphasis.bold,
        controlCodesStyle = controlCodesStyle ?? punctuation,
        colonStyle = colonStyle ?? punctuation,
        ellipsisStyle = ellipsisStyle ?? punctuation,
        lineBreakStyle = lineBreakStyle ?? punctuation,
        paddingStyle = paddingStyle ?? punctuation,
        sectionStyle = sectionStyle ?? emphasis.bold,
        dataKeyStyle = dataKeyStyle ?? emphasis,
        dataUnitsStyle = dataUnitsStyle ?? dim,
        stackTraceActiveStyle = stackTraceActiveStyle ?? emphasis,
        stackTraceInactiveStyle = stackTraceInactiveStyle ?? dim;

  static const LogLevelTheme noColors = LogLevelTheme(
    normal: ansi.NoStyle(),
    inverse: ansi.NoStyle(),
    bold: ansi.NoStyle(),
    emphasis: ansi.NoStyle(),
    dim: ansi.NoStyle(),
    punctuation: ansi.NoStyle(),
    sequenceNumStyle: ansi.NoStyle(),
    levelNameStyle: ansi.NoStyle(),
    timeStyle: ansi.NoStyle(),
    pathStyle: ansi.NoStyle(),
    messageStyles: {},
    valueFormatter: ControlCodeFormatter(),
    messageFormatter: BbCodeFormatter(),
    controlCodesStyle: ansi.NoStyle(),
    colonStyle: ansi.NoStyle(),
    ellipsisStyle: ansi.NoStyle(),
    lineBreakStyle: ansi.NoStyle(),
    paddingStyle: ansi.NoStyle(),
    sectionStyle: ansi.NoStyle(),
    dataNameStyle: ansi.NoStyle(),
    dataKeyStyle: ansi.NoStyle(),
    dataValueStyle: ansi.NoStyle(),
    dataUnitsStyle: ansi.NoStyle(),
    dataBlockTheme: [LogDataBlockTheme.noStyle()],
    stackTraceActiveStyle: ansi.NoStyle(),
    stackTraceInactiveStyle: ansi.NoStyle(),
  );

  static const _black = ansi.Color256.gray0;

  static const _redDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb511, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb511),
    description: ansi.Style(foreground: ansi.Color256.rgb400),
  );

  static const _redMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb410, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb410),
    description: ansi.Style(foreground: ansi.Color256.rgb300),
  );

  static const _orangeDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb530, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb530),
    description: ansi.Style(foreground: ansi.Color256.rgb420),
  );

  static const _orangeMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb420, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb420),
    description: ansi.Style(foreground: ansi.Color256.rgb310),
  );

  static const _yellowDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb550, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb550),
    description: ansi.Style(foreground: ansi.Color256.rgb440),
  );

  static const _yellowMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb440, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb440),
    description: ansi.Style(foreground: ansi.Color256.rgb330),
  );

  static const _greenDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb051, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb051),
    description: ansi.Style(foreground: ansi.Color256.rgb040),
  );

  static const _greenMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb040, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb040),
    description: ansi.Style(foreground: ansi.Color256.rgb030),
  );

  static const _blueDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb035, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb035),
    description: ansi.Style(foreground: ansi.Color256.rgb024),
  );

  static const _blueMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb024, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb024),
    description: ansi.Style(foreground: ansi.Color256.rgb013),
  );

  static const _magentaDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb515, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb515),
    description: ansi.Style(foreground: ansi.Color256.rgb404),
  );

  static const _magentaMutedDataBlockTheme = LogDataBlockTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb404, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb404),
    description: ansi.Style(foreground: ansi.Color256.rgb303),
  );

  static const defaultPunctuation = ansi.rgb055;
  static const defaultMutedPunctuation = ansi.rgb044;

  static const defaultDataBlockThemesWoBM = [
    _yellowDataBlockTheme,
    _greenDataBlockTheme,
    _orangeDataBlockTheme,
    _redDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoBM = [
    _yellowMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _redMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoBR = [
    _yellowDataBlockTheme,
    _greenDataBlockTheme,
    _orangeDataBlockTheme,
    _magentaDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoBR = [
    _yellowMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoBG = [
    _yellowDataBlockTheme,
    _orangeDataBlockTheme,
    _magentaDataBlockTheme,
    _redDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoBG = [
    _yellowMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
    _redMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoGR = [
    _yellowDataBlockTheme,
    _blueDataBlockTheme,
    _orangeDataBlockTheme,
    _magentaDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoGR = [
    _yellowMutedDataBlockTheme,
    _blueMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoYG = [
    _blueDataBlockTheme,
    _orangeDataBlockTheme,
    _magentaDataBlockTheme,
    _redDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoYG = [
    _blueMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
    _redMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoYO = [
    _blueDataBlockTheme,
    _greenDataBlockTheme,
    _magentaDataBlockTheme,
    _redDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoYO = [
    _blueMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
    _redMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoYR = [
    _blueDataBlockTheme,
    _greenDataBlockTheme,
    _orangeDataBlockTheme,
    _magentaDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoYR = [
    _blueMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoOR = [
    _yellowDataBlockTheme,
    _blueDataBlockTheme,
    _greenDataBlockTheme,
    _magentaDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoOR = [
    _yellowMutedDataBlockTheme,
    _blueMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _magentaMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoOM = [
    _yellowDataBlockTheme,
    _blueDataBlockTheme,
    _greenDataBlockTheme,
    _redDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoOM = [
    _yellowMutedDataBlockTheme,
    _blueMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _redMutedDataBlockTheme,
  ];

  static const defaultDataBlockThemesWoMR = [
    _yellowDataBlockTheme,
    _blueDataBlockTheme,
    _greenDataBlockTheme,
    _orangeDataBlockTheme,
  ];

  static const defaultMutedDataBlockThemesWoMR = [
    _yellowMutedDataBlockTheme,
    _blueMutedDataBlockTheme,
    _greenMutedDataBlockTheme,
    _orangeMutedDataBlockTheme,
  ];

  static const Map<String, ansi.Style> defaultMessageStyles = {
    'b': ansi.NoStyle(),
    'success': ansi.rgb050,
    'error': ansi.rgb500,
  };

  static const Map<String, ansi.Style> defaultMutedMessageStyles = {
    'b': ansi.NoStyle(),
    'success': ansi.rgb040,
    'error': ansi.rgb400,
  };

  static final gray5 = LogLevelTheme.seed(
    normal: ansi.gray5,
    emphasis: ansi.gray8,
    dim: ansi.gray3,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray6 = LogLevelTheme.seed(
    normal: ansi.gray6,
    emphasis: ansi.gray9,
    dim: ansi.gray4,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray7 = LogLevelTheme.seed(
    normal: ansi.gray7,
    emphasis: ansi.gray10,
    dim: ansi.gray5,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray8 = LogLevelTheme.seed(
    normal: ansi.gray8,
    emphasis: ansi.gray11,
    dim: ansi.gray6,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray9 = LogLevelTheme.seed(
    normal: ansi.gray9,
    emphasis: ansi.gray12,
    dim: ansi.gray7,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray10 = LogLevelTheme.seed(
    normal: ansi.gray10,
    emphasis: ansi.gray14,
    dim: ansi.gray7,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray11 = LogLevelTheme.seed(
    normal: ansi.gray11,
    emphasis: ansi.gray15,
    dim: ansi.gray8,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final gray12 = LogLevelTheme.seed(
    normal: ansi.gray12,
    emphasis: ansi.gray16,
    dim: ansi.gray9,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray13 = LogLevelTheme.seed(
    normal: ansi.gray13,
    emphasis: ansi.gray17,
    dim: ansi.gray10,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray14 = LogLevelTheme.seed(
    normal: ansi.gray14,
    emphasis: ansi.gray18,
    dim: ansi.gray11,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray15 = LogLevelTheme.seed(
    normal: ansi.gray15,
    emphasis: ansi.gray19,
    dim: ansi.gray12,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray16 = LogLevelTheme.seed(
    normal: ansi.gray16,
    emphasis: ansi.gray20,
    dim: ansi.gray13,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray17 = LogLevelTheme.seed(
    normal: ansi.gray17,
    emphasis: ansi.gray22,
    dim: ansi.gray13,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray18 = LogLevelTheme.seed(
    normal: ansi.gray18,
    emphasis: ansi.gray23,
    dim: ansi.gray14,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray19 = LogLevelTheme.seed(
    normal: ansi.gray19,
    emphasis: ansi.gray23,
    dim: ansi.gray15,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final gray20 = LogLevelTheme.seed(
    normal: ansi.gray20,
    emphasis: ansi.gray23,
    dim: ansi.gray16,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final rgb444 = LogLevelTheme.seed(
    normal: ansi.rgb444,
    emphasis: ansi.rgb555,
    dim: ansi.rgb333,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final rgb443 = LogLevelTheme.seed(
    normal: ansi.rgb443,
    emphasis: ansi.rgb554,
    dim: ansi.rgb332,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb442 = LogLevelTheme.seed(
    normal: ansi.rgb442,
    emphasis: ansi.rgb553,
    dim: ansi.rgb331,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb441 = LogLevelTheme.seed(
    normal: ansi.rgb441,
    emphasis: ansi.rgb552,
    dim: ansi.rgb330,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb440 = LogLevelTheme.seed(
    normal: ansi.rgb440,
    emphasis: ansi.rgb550,
    dim: ansi.rgb330,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb434 = LogLevelTheme.seed(
    normal: ansi.rgb434,
    emphasis: ansi.rgb545,
    dim: ansi.rgb323,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb433 = LogLevelTheme.seed(
    normal: ansi.rgb433,
    emphasis: ansi.rgb544,
    dim: ansi.rgb322,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb432 = LogLevelTheme.seed(
    normal: ansi.rgb432,
    emphasis: ansi.rgb543,
    dim: ansi.rgb321,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb431 = LogLevelTheme.seed(
    normal: ansi.rgb431,
    emphasis: ansi.rgb542,
    dim: ansi.rgb320,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb430 = LogLevelTheme.seed(
    normal: ansi.rgb430,
    emphasis: ansi.rgb540,
    dim: ansi.rgb320,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb424 = LogLevelTheme.seed(
    normal: ansi.rgb424,
    emphasis: ansi.rgb535,
    dim: ansi.rgb313,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb423 = LogLevelTheme.seed(
    normal: ansi.rgb423,
    emphasis: ansi.rgb534,
    dim: ansi.rgb312,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb422 = LogLevelTheme.seed(
    normal: ansi.rgb422,
    emphasis: ansi.rgb533,
    dim: ansi.rgb311,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb421 = LogLevelTheme.seed(
    normal: ansi.rgb421,
    emphasis: ansi.rgb532,
    dim: ansi.rgb310,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb420 = LogLevelTheme.seed(
    normal: ansi.rgb420,
    emphasis: ansi.rgb530,
    dim: ansi.rgb310,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb414 = LogLevelTheme.seed(
    normal: ansi.rgb414,
    emphasis: ansi.rgb525,
    dim: ansi.rgb303,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb413 = LogLevelTheme.seed(
    normal: ansi.rgb413,
    emphasis: ansi.rgb524,
    dim: ansi.rgb302,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb412 = LogLevelTheme.seed(
    normal: ansi.rgb412,
    emphasis: ansi.rgb523,
    dim: ansi.rgb301,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb411 = LogLevelTheme.seed(
    normal: ansi.rgb411,
    emphasis: ansi.rgb522,
    dim: ansi.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb410 = LogLevelTheme.seed(
    normal: ansi.rgb410,
    emphasis: ansi.rgb520,
    dim: ansi.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb404 = LogLevelTheme.seed(
    normal: ansi.rgb404,
    emphasis: ansi.rgb505,
    dim: ansi.rgb303,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb403 = LogLevelTheme.seed(
    normal: ansi.rgb403,
    emphasis: ansi.rgb504,
    dim: ansi.rgb302,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb402 = LogLevelTheme.seed(
    normal: ansi.rgb402,
    emphasis: ansi.rgb503,
    dim: ansi.rgb301,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb401 = LogLevelTheme.seed(
    normal: ansi.rgb401,
    emphasis: ansi.rgb502,
    dim: ansi.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb400 = LogLevelTheme.seed(
    normal: ansi.rgb400,
    emphasis: ansi.rgb500,
    dim: ansi.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb344 = LogLevelTheme.seed(
    normal: ansi.rgb344,
    emphasis: ansi.rgb455,
    dim: ansi.rgb233,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb343 = LogLevelTheme.seed(
    normal: ansi.rgb343,
    emphasis: ansi.rgb454,
    dim: ansi.rgb232,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb342 = LogLevelTheme.seed(
    normal: ansi.rgb342,
    emphasis: ansi.rgb453,
    dim: ansi.rgb231,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb341 = LogLevelTheme.seed(
    normal: ansi.rgb341,
    emphasis: ansi.rgb452,
    dim: ansi.rgb230,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb340 = LogLevelTheme.seed(
    normal: ansi.rgb340,
    emphasis: ansi.rgb450,
    dim: ansi.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb334 = LogLevelTheme.seed(
    normal: ansi.rgb334,
    emphasis: ansi.rgb445,
    dim: ansi.rgb223,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb333 = LogLevelTheme.seed(
    normal: ansi.rgb333,
    emphasis: ansi.rgb444,
    dim: ansi.rgb222,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final rgb332 = LogLevelTheme.seed(
    normal: ansi.rgb332,
    emphasis: ansi.rgb443,
    dim: ansi.rgb221,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb331 = LogLevelTheme.seed(
    normal: ansi.rgb331,
    emphasis: ansi.rgb442,
    dim: ansi.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb330 = LogLevelTheme.seed(
    normal: ansi.rgb330,
    emphasis: ansi.rgb440,
    dim: ansi.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb324 = LogLevelTheme.seed(
    normal: ansi.rgb324,
    emphasis: ansi.rgb435,
    dim: ansi.rgb213,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb323 = LogLevelTheme.seed(
    normal: ansi.rgb323,
    emphasis: ansi.rgb434,
    dim: ansi.rgb212,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb322 = LogLevelTheme.seed(
    normal: ansi.rgb322,
    emphasis: ansi.rgb433,
    dim: ansi.rgb211,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb321 = LogLevelTheme.seed(
    normal: ansi.rgb321,
    emphasis: ansi.rgb432,
    dim: ansi.rgb210,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoOR,
  );

  static final rgb320 = LogLevelTheme.seed(
    normal: ansi.rgb320,
    emphasis: ansi.rgb430,
    dim: ansi.rgb210,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYO,
  );

  static final rgb314 = LogLevelTheme.seed(
    normal: ansi.rgb314,
    emphasis: ansi.rgb425,
    dim: ansi.rgb203,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb313 = LogLevelTheme.seed(
    normal: ansi.rgb313,
    emphasis: ansi.rgb424,
    dim: ansi.rgb202,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb312 = LogLevelTheme.seed(
    normal: ansi.rgb312,
    emphasis: ansi.rgb423,
    dim: ansi.rgb201,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb311 = LogLevelTheme.seed(
    normal: ansi.rgb311,
    emphasis: ansi.rgb422,
    dim: ansi.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb310 = LogLevelTheme.seed(
    normal: ansi.rgb310,
    emphasis: ansi.rgb420,
    dim: ansi.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb304 = LogLevelTheme.seed(
    normal: ansi.rgb304,
    emphasis: ansi.rgb405,
    dim: ansi.rgb203,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoMR,
  );

  static final rgb303 = LogLevelTheme.seed(
    normal: ansi.rgb303,
    emphasis: ansi.rgb404,
    dim: ansi.rgb202,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb302 = LogLevelTheme.seed(
    normal: ansi.rgb302,
    emphasis: ansi.rgb403,
    dim: ansi.rgb201,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb301 = LogLevelTheme.seed(
    normal: ansi.rgb301,
    emphasis: ansi.rgb402,
    dim: ansi.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb300 = LogLevelTheme.seed(
    normal: ansi.rgb300,
    emphasis: ansi.rgb400,
    dim: ansi.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb244 = LogLevelTheme.seed(
    normal: ansi.rgb244,
    emphasis: ansi.rgb355,
    dim: ansi.rgb133,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb243 = LogLevelTheme.seed(
    normal: ansi.rgb243,
    emphasis: ansi.rgb354,
    dim: ansi.rgb132,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb242 = LogLevelTheme.seed(
    normal: ansi.rgb242,
    emphasis: ansi.rgb353,
    dim: ansi.rgb131,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb241 = LogLevelTheme.seed(
    normal: ansi.rgb241,
    emphasis: ansi.rgb352,
    dim: ansi.rgb130,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb240 = LogLevelTheme.seed(
    normal: ansi.rgb240,
    emphasis: ansi.rgb350,
    dim: ansi.rgb130,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb234 = LogLevelTheme.seed(
    normal: ansi.rgb234,
    emphasis: ansi.rgb345,
    dim: ansi.rgb123,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb233 = LogLevelTheme.seed(
    normal: ansi.rgb233,
    emphasis: ansi.rgb344,
    dim: ansi.rgb122,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb232 = LogLevelTheme.seed(
    normal: ansi.rgb232,
    emphasis: ansi.rgb343,
    dim: ansi.rgb121,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb231 = LogLevelTheme.seed(
    normal: ansi.rgb231,
    emphasis: ansi.rgb342,
    dim: ansi.rgb120,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb230 = LogLevelTheme.seed(
    normal: ansi.rgb230,
    emphasis: ansi.rgb340,
    dim: ansi.rgb120,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb224 = LogLevelTheme.seed(
    normal: ansi.rgb224,
    emphasis: ansi.rgb335,
    dim: ansi.rgb113,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb223 = LogLevelTheme.seed(
    normal: ansi.rgb223,
    emphasis: ansi.rgb334,
    dim: ansi.rgb112,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb222 = LogLevelTheme.seed(
    normal: ansi.rgb222,
    emphasis: ansi.rgb333,
    dim: ansi.rgb111,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoGR,
  );

  static final rgb221 = LogLevelTheme.seed(
    normal: ansi.rgb221,
    emphasis: ansi.rgb332,
    dim: ansi.rgb110,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb220 = LogLevelTheme.seed(
    normal: ansi.rgb220,
    emphasis: ansi.rgb330,
    dim: ansi.rgb110,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb214 = LogLevelTheme.seed(
    normal: ansi.rgb214,
    emphasis: ansi.rgb325,
    dim: ansi.rgb103,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb213 = LogLevelTheme.seed(
    normal: ansi.rgb213,
    emphasis: ansi.rgb324,
    dim: ansi.rgb102,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb212 = LogLevelTheme.seed(
    normal: ansi.rgb212,
    emphasis: ansi.rgb323,
    dim: ansi.rgb101,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb211 = LogLevelTheme.seed(
    normal: ansi.rgb211,
    emphasis: ansi.rgb322,
    dim: ansi.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb210 = LogLevelTheme.seed(
    normal: ansi.rgb210,
    emphasis: ansi.rgb320,
    dim: ansi.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYO,
  );

  static final rgb204 = LogLevelTheme.seed(
    normal: ansi.rgb204,
    emphasis: ansi.rgb305,
    dim: ansi.rgb103,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb203 = LogLevelTheme.seed(
    normal: ansi.rgb203,
    emphasis: ansi.rgb304,
    dim: ansi.rgb102,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb202 = LogLevelTheme.seed(
    normal: ansi.rgb202,
    emphasis: ansi.rgb303,
    dim: ansi.rgb101,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb201 = LogLevelTheme.seed(
    normal: ansi.rgb201,
    emphasis: ansi.rgb302,
    dim: ansi.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoMR,
  );

  static final rgb200 = LogLevelTheme.seed(
    normal: ansi.rgb200,
    emphasis: ansi.rgb300,
    dim: ansi.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoOR,
  );

  static final rgb144 = LogLevelTheme.seed(
    normal: ansi.rgb144,
    emphasis: ansi.rgb255,
    dim: ansi.rgb033,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb143 = LogLevelTheme.seed(
    normal: ansi.rgb143,
    emphasis: ansi.rgb254,
    dim: ansi.rgb032,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final rgb142 = LogLevelTheme.seed(
    normal: ansi.rgb142,
    emphasis: ansi.rgb253,
    dim: ansi.rgb031,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb141 = LogLevelTheme.seed(
    normal: ansi.rgb141,
    emphasis: ansi.rgb252,
    dim: ansi.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb140 = LogLevelTheme.seed(
    normal: ansi.rgb140,
    emphasis: ansi.rgb250,
    dim: ansi.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb134 = LogLevelTheme.seed(
    normal: ansi.rgb134,
    emphasis: ansi.rgb245,
    dim: ansi.rgb023,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb133 = LogLevelTheme.seed(
    normal: ansi.rgb133,
    emphasis: ansi.rgb244,
    dim: ansi.rgb022,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb132 = LogLevelTheme.seed(
    normal: ansi.rgb132,
    emphasis: ansi.rgb243,
    dim: ansi.rgb021,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoGR,
  );

  static final rgb131 = LogLevelTheme.seed(
    normal: ansi.rgb131,
    emphasis: ansi.rgb242,
    dim: ansi.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb130 = LogLevelTheme.seed(
    normal: ansi.rgb130,
    emphasis: ansi.rgb240,
    dim: ansi.rgb020,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb124 = LogLevelTheme.seed(
    normal: ansi.rgb124,
    emphasis: ansi.rgb235,
    dim: ansi.rgb013,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb123 = LogLevelTheme.seed(
    normal: ansi.rgb123,
    emphasis: ansi.rgb234,
    dim: ansi.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb122 = LogLevelTheme.seed(
    normal: ansi.rgb122,
    emphasis: ansi.rgb233,
    dim: ansi.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBG,
  );

  static final rgb121 = LogLevelTheme.seed(
    normal: ansi.rgb121,
    emphasis: ansi.rgb232,
    dim: ansi.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb120 = LogLevelTheme.seed(
    normal: ansi.rgb120,
    emphasis: ansi.rgb230,
    dim: ansi.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb114 = LogLevelTheme.seed(
    normal: ansi.rgb114,
    emphasis: ansi.rgb225,
    dim: ansi.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb113 = LogLevelTheme.seed(
    normal: ansi.rgb113,
    emphasis: ansi.rgb224,
    dim: ansi.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb112 = LogLevelTheme.seed(
    normal: ansi.rgb112,
    emphasis: ansi.rgb223,
    dim: ansi.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb104 = LogLevelTheme.seed(
    normal: ansi.rgb104,
    emphasis: ansi.rgb205,
    dim: ansi.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb103 = LogLevelTheme.seed(
    normal: ansi.rgb103,
    emphasis: ansi.rgb204,
    dim: ansi.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb102 = LogLevelTheme.seed(
    normal: ansi.rgb102,
    emphasis: ansi.rgb203,
    dim: ansi.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBM,
  );

  static final rgb044 = LogLevelTheme.seed(
    normal: ansi.rgb044,
    emphasis: ansi.rgb055,
    dim: ansi.rgb033,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb043 = LogLevelTheme.seed(
    normal: ansi.rgb043,
    emphasis: ansi.rgb054,
    dim: ansi.rgb032,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb042 = LogLevelTheme.seed(
    normal: ansi.rgb042,
    emphasis: ansi.rgb053,
    dim: ansi.rgb031,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb041 = LogLevelTheme.seed(
    normal: ansi.rgb041,
    emphasis: ansi.rgb050,
    dim: ansi.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb040 = LogLevelTheme.seed(
    normal: ansi.rgb040,
    emphasis: ansi.rgb050,
    dim: ansi.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb034 = LogLevelTheme.seed(
    normal: ansi.rgb034,
    emphasis: ansi.rgb045,
    dim: ansi.rgb023,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBR,
  );

  static final rgb033 = LogLevelTheme.seed(
    normal: ansi.rgb033,
    emphasis: ansi.rgb044,
    dim: ansi.rgb022,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb032 = LogLevelTheme.seed(
    normal: ansi.rgb032,
    emphasis: ansi.rgb043,
    dim: ansi.rgb021,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoBG,
  );

  static final rgb031 = LogLevelTheme.seed(
    normal: ansi.rgb031,
    emphasis: ansi.rgb042,
    dim: ansi.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb030 = LogLevelTheme.seed(
    normal: ansi.rgb030,
    emphasis: ansi.rgb040,
    dim: ansi.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    dataBlockTheme: defaultDataBlockThemesWoYG,
  );

  static final rgb024 = LogLevelTheme.seed(
    normal: ansi.rgb024,
    emphasis: ansi.rgb035,
    dim: ansi.rgb013,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb023 = LogLevelTheme.seed(
    normal: ansi.rgb023,
    emphasis: ansi.rgb034,
    dim: ansi.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb022 = LogLevelTheme.seed(
    normal: ansi.rgb022,
    emphasis: ansi.rgb033,
    dim: ansi.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBG,
  );

  static final rgb021 = LogLevelTheme.seed(
    normal: ansi.rgb021,
    emphasis: ansi.rgb032,
    dim: ansi.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb020 = LogLevelTheme.seed(
    normal: ansi.rgb020,
    emphasis: ansi.rgb030,
    dim: ansi.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoYG,
  );

  static final rgb014 = LogLevelTheme.seed(
    normal: ansi.rgb014,
    emphasis: ansi.rgb025,
    dim: ansi.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb013 = LogLevelTheme.seed(
    normal: ansi.rgb013,
    emphasis: ansi.rgb024,
    dim: ansi.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb012 = LogLevelTheme.seed(
    normal: ansi.rgb012,
    emphasis: ansi.rgb023,
    dim: ansi.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb004 = LogLevelTheme.seed(
    normal: ansi.rgb004,
    emphasis: ansi.rgb005,
    dim: ansi.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb003 = LogLevelTheme.seed(
    normal: ansi.rgb003,
    emphasis: ansi.rgb004,
    dim: ansi.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  static final rgb002 = LogLevelTheme.seed(
    normal: ansi.rgb002,
    emphasis: ansi.rgb003,
    dim: ansi.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    dataBlockTheme: defaultMutedDataBlockThemesWoBR,
  );

  void attach(LogTheme parent) {
    _mainThemeExpando[this] = parent;
  }

  LogTheme get common => _mainThemeExpando[this] ?? LogTheme.noColors;

  String get styledColon => colonStyle(common.colon);

  AnsiPair get colonAnsiPair => AnsiPair(common.colon, colonStyle);

  String get styledEllipsis => ellipsisStyle(common.ellipsis);

  AnsiPair get ellipsisAnsiPair => AnsiPair(common.ellipsis, ellipsisStyle);

  String get styledLineBreak => lineBreakStyle(common.lineBreak);

  AnsiPair get lineBreakAnsiPair => AnsiPair(common.lineBreak, lineBreakStyle);

  String get styledPadding => paddingStyle(common.padding);

  AnsiPair get paddingAnsiPair => AnsiPair(common.padding, paddingStyle);

  String formatValue(String value) => valueFormatter(this, value);

  String formatMessage(String value) => messageFormatter(this, value);

  String formatSectionName(String name) =>
      common.sectionNameFormatter(this, name);

  String formatIndex(int index) => common.indexFormatter(this, index);

  String formatCount(int count) => common.countFormatter(this, count);

  LogDataBlockTheme dataBlockStyle(int level) =>
      dataBlockTheme[level % dataBlockTheme.length];

  Set<String> allTags(Log log) => {...common.tags, ...tags, ...log.tags};

  LogLevelTheme copyWith({
    ansi.Style? normal,
    ansi.Style? inverse,
    ansi.Style? bold,
    ansi.Style? emphasis,
    ansi.Style? dim,
    ansi.Style? sequenceNumStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    Map<String, ansi.Style>? messageStyles,
    LogPreFormatter? valueFormatter,
    LogPreFormatter? messageFormatter,
    ansi.Style? controlCodesStyle,
    ansi.Style? punctuation,
    String? colon,
    ansi.Style? colonStyle,
    String? ellipsis,
    ansi.Style? ellipsisStyle,
    String? lineBreak,
    ansi.Style? lineBreakStyle,
    String? padding,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    ansi.Style? dataNameStyle,
    ansi.Style? dataKeyStyle,
    ansi.Style? dataValueStyle,
    ansi.Style? dataUnitsStyle,
    List<LogDataBlockTheme>? dataBlockTheme,
    ansi.Style? stackTraceActiveStyle,
    ansi.Style? stackTraceInactiveStyle,
    Set<String>? tags,
  }) {
    assert(padding == null || padding.length == 1);

    return LogLevelTheme(
      normal: normal ?? this.normal,
      inverse: inverse ?? this.inverse,
      bold: bold ?? this.bold,
      emphasis: emphasis ?? this.emphasis,
      dim: dim ?? this.dim,
      sequenceNumStyle: sequenceNumStyle ?? this.sequenceNumStyle,
      levelNameStyle: levelNameStyle ?? this.levelNameStyle,
      timeStyle: timeStyle ?? this.timeStyle,
      pathStyle: pathStyle ?? this.pathStyle,
      messageStyles: messageStyles ?? this.messageStyles,
      valueFormatter: valueFormatter ?? this.valueFormatter,
      messageFormatter: messageFormatter ?? this.messageFormatter,
      controlCodesStyle: controlCodesStyle ?? this.controlCodesStyle,
      punctuation: punctuation ?? this.punctuation,
      colonStyle: colonStyle ?? this.colonStyle,
      ellipsisStyle: ellipsisStyle ?? this.ellipsisStyle,
      lineBreakStyle: lineBreakStyle ?? this.lineBreakStyle,
      paddingStyle: paddingStyle ?? this.paddingStyle,
      sectionStyle: sectionStyle ?? this.sectionStyle,
      dataNameStyle: dataNameStyle ?? this.dataNameStyle,
      dataKeyStyle: dataKeyStyle ?? this.dataKeyStyle,
      dataValueStyle: dataValueStyle ?? this.dataValueStyle,
      dataUnitsStyle: dataUnitsStyle ?? this.dataUnitsStyle,
      dataBlockTheme: dataBlockTheme ?? this.dataBlockTheme,
      stackTraceActiveStyle:
          stackTraceActiveStyle ?? this.stackTraceActiveStyle,
      stackTraceInactiveStyle:
          stackTraceInactiveStyle ?? this.stackTraceInactiveStyle,
      tags: tags ?? this.tags,
    );
  }

  LogLevelTheme copyWithMainStyles({
    required ansi.Style normal,
    ansi.Style? inverse,
    required ansi.Style emphasis,
    ansi.Style? bold,
    required ansi.Style dim,
    List<LogDataBlockTheme>? dataBlockTheme,
  }) {
    bold ??= emphasis.bold;
    inverse ??= ansi.Style(
      foreground: _black,
      background: normal.foregroundColor,
    );

    return copyWith(
      normal: normal,
      inverse: inverse,
      bold: bold,
      emphasis: emphasis,
      dim: dim,
      levelNameStyle: inverse,
      pathStyle: emphasis,
      messageStyles: Map.of(messageStyles)..['b'] = bold,
      sectionStyle: bold,
      dataKeyStyle: emphasis,
      dataUnitsStyle: dim,
      dataBlockTheme: dataBlockTheme,
      stackTraceActiveStyle: emphasis,
      stackTraceInactiveStyle: dim,
    );
  }

  LogLevelTheme copyWithPunctuation(
    ansi.Style punctuation, {
    bool setForControlCodes = true,
    bool setForColon = true,
    bool setForEllipsis = true,
    bool setForLineBreak = true,
    bool setForPadding = true,
  }) =>
      copyWith(
        punctuation: punctuation,
        controlCodesStyle: setForControlCodes ? punctuation : null,
        colonStyle: setForColon ? punctuation : null,
        ellipsisStyle: setForEllipsis ? punctuation : null,
        lineBreakStyle: setForLineBreak ? punctuation : null,
        paddingStyle: setForPadding ? punctuation : null,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..style('normal', null, normal)
      ..style('inverse', null, inverse)
      ..style('bold', null, bold)
      ..style('emphasis', null, emphasis)
      ..style('dim', null, dim)
      ..style('punctuation', null, punctuation)
      ..style('sequenceNumStyle', this, sequenceNumStyle)
      ..style('levelNameStyle', this, levelNameStyle)
      ..style('timeStyle', this, timeStyle)
      ..style('pathStyle', this, pathStyle)
      ..mapStyles('messageStyles', messageStyles)
      ..prop('valueFormatter', valueFormatter)
      ..prop('messageFormatter', messageFormatter)
      ..style('controlCodesStyle', this, controlCodesStyle)
      ..style('colonStyle', this, colonStyle)
      ..style('ellipsisStyle', this, ellipsisStyle)
      ..style('lineBreakStyle', this, lineBreakStyle)
      ..style('paddingStyle', this, paddingStyle)
      ..style('sectionStyle', this, sectionStyle)
      ..style('dataNameStyle', this, dataNameStyle)
      ..style('dataKeyStyle', this, dataKeyStyle)
      ..style('dataValueStyle', this, dataValueStyle)
      ..style('dataUnitsStyle', this, dataUnitsStyle)
      ..blockTheme('dataBlockTheme', dataBlockTheme)
      ..style('stackTraceActiveStyle', this, stackTraceActiveStyle)
      ..style('stackTraceInactiveStyle', this, stackTraceInactiveStyle)
      ..prop('tags', tags);
  }
}

final class LogDataBlockTheme {
  final ansi.Style brackets;
  final ansi.Style punctuation;
  final ansi.Style description;

  const LogDataBlockTheme({
    required this.brackets,
    required this.punctuation,
    required this.description,
  });

  const LogDataBlockTheme.noStyle()
      : brackets = const ansi.NoStyle(),
        punctuation = const ansi.NoStyle(),
        description = const ansi.NoStyle();
}

extension on LoggableData {
  void style(
    String name,
    LogLevelTheme? theme,
    ansi.Style style, {
    bool showName = false,
  }) {
    if (theme case final theme?) {
      if (style is ansi.NoStyle || style == theme.normal) {
        prop(name, style, view: theme.normal('normal'));
        return;
      }
      if (style == theme.inverse) {
        prop(name, style, view: theme.inverse('inverse'));
        return;
      }
      if (style == theme.emphasis) {
        prop(name, style, view: theme.emphasis('emphasis'));
        return;
      }
      if (style == theme.bold) {
        prop(name, style, view: theme.bold('bold'));
        return;
      }
      if (style == theme.dim) {
        prop(name, style, view: theme.dim('dim'));
        return;
      }
      if (style == theme.punctuation) {
        prop(name, style, view: theme.punctuation('punctuation'));
        return;
      }
    }
    if (style is ansi.NoStyle) {
      prop(name, style, view: '-');
      return;
    }

    prop(name, style, showName: showName, view: style(name));
  }

  void blockTheme(
    String name,
    List<LogDataBlockTheme> styles,
  ) {
    final none = styles.fold(
      false,
      (none, style) =>
          none ||
          style.brackets is ansi.NoStyle &&
              style.description is ansi.NoStyle &&
              style.punctuation is ansi.NoStyle,
    );
    if (none) {
      prop(name, styles, view: '-');
      return;
    }

    final values = styles
        .map(
          (e) => '${e.brackets('[')}'
              '${e.description('₌₄')}'
              '${e.punctuation('…')}'
              '${e.brackets(']')}',
        )
        .join();
    prop(name, styles, view: '"$values"');
  }

  void mapStyles(String name, Map<String, ansi.Style> styles) {
    final map = LoggableMap();
    for (final MapEntry(:key, value: style) in styles.entries) {
      map.prop(key, style, showName: false, view: style(key));
    }

    prop(name, map);
  }
}
