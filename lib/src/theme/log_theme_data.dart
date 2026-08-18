part of 'log_main_theme.dart';

final class LogThemeData with Loggable {
  final ansi.Style normal;
  final ansi.Style inverse;
  final ansi.Style bold;
  final ansi.Style emphasis;
  final ansi.Style dim;
  final ansi.Style punctuation;
  final ansi.Style numStyle;
  final ansi.Style levelNameStyle;
  final ansi.Style timeStyle;
  final ansi.Style pathStyle;
  final Map<String, LogStyle> messageStyles;
  final ansi.Style controlCodesStyle;
  final ansi.Style quotesStyle;
  final ansi.Style colonStyle;
  final ansi.Style ellipsisStyle;
  final ansi.Style lineBreakStyle;
  final ansi.Style paddingStyle;
  final ansi.Style sectionStyle;
  final ansi.Style nameStyle;
  final ansi.Style keyStyle;
  final ansi.Style valueStyle;
  final ansi.Style unitsStyle;
  final List<LogDepthTheme> depthThemes;
  final ansi.Style stackTraceActiveStyle;
  final ansi.Style stackTraceInactiveStyle;
  final Set<String> tags;

  const LogThemeData({
    required this.normal,
    required this.inverse,
    required this.bold,
    required this.emphasis,
    required this.dim,
    required this.punctuation,
    required this.numStyle,
    required this.levelNameStyle,
    required this.timeStyle,
    required this.pathStyle,
    required this.messageStyles,
    required this.controlCodesStyle,
    required this.quotesStyle,
    required this.colonStyle,
    required this.ellipsisStyle,
    required this.lineBreakStyle,
    required this.paddingStyle,
    required this.sectionStyle,
    required this.nameStyle,
    required this.keyStyle,
    required this.valueStyle,
    required this.unitsStyle,
    required this.depthThemes,
    required this.stackTraceActiveStyle,
    required this.stackTraceInactiveStyle,
    this.tags = const {},
  });

  LogThemeData.seed({
    required this.normal,
    required this.emphasis,
    required this.dim,
    required this.punctuation,
    ansi.Style? bold,
    ansi.Style? inverse,
    ansi.Style? numStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    Map<String, LogStyle>? messageStyles,
    ansi.Style? controlCodesStyle,
    ansi.Style? quotesStyle,
    ansi.Style? colonStyle,
    ansi.Style? ellipsisStyle,
    ansi.Style? lineBreakStyle,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    ansi.Style? nameStyle,
    ansi.Style? keyStyle,
    ansi.Style? valueStyle,
    ansi.Style? unitsStyle,
    required this.depthThemes,
    ansi.Style? stackTraceActiveStyle,
    ansi.Style? stackTraceInactiveStyle,
    Set<String>? tags,
  })  : bold = bold ?? emphasis.bold,
        inverse = inverse ??
            ansi.Style(
              foreground: _black,
              background: normal.foregroundColor,
            ),
        numStyle = numStyle ?? const ansi.NoStyle(),
        levelNameStyle = levelNameStyle ??
            inverse ??
            ansi.Style(
              foreground: _black,
              background: normal.foregroundColor,
            ),
        timeStyle = timeStyle ?? const ansi.NoStyle(),
        pathStyle = pathStyle ?? emphasis,
        messageStyles = messageStyles ?? defaultMessageStyles,
        controlCodesStyle = controlCodesStyle ?? punctuation,
        quotesStyle = quotesStyle ?? punctuation,
        colonStyle = colonStyle ?? punctuation,
        ellipsisStyle = ellipsisStyle ?? punctuation,
        lineBreakStyle = lineBreakStyle ?? punctuation,
        paddingStyle = paddingStyle ?? punctuation,
        sectionStyle = sectionStyle ?? emphasis.bold,
        nameStyle = nameStyle ?? const ansi.NoStyle(),
        keyStyle = keyStyle ?? emphasis,
        valueStyle = valueStyle ?? const ansi.NoStyle(),
        unitsStyle = unitsStyle ?? dim,
        stackTraceActiveStyle = stackTraceActiveStyle ?? emphasis,
        stackTraceInactiveStyle = stackTraceInactiveStyle ?? dim,
        tags = tags ?? const {};

  LogThemeData.inactiveSeed({
    required this.normal,
    ansi.Style? emphasis,
    ansi.Style? dim,
    ansi.Style? punctuation,
    ansi.Style? bold,
    ansi.Style? inverse,
    ansi.Style? numStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    Map<String, LogStyle>? messageStyles,
    ansi.Style? controlCodesStyle,
    ansi.Style? quotesStyle,
    ansi.Style? colonStyle,
    ansi.Style? ellipsisStyle,
    ansi.Style? lineBreakStyle,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    ansi.Style? nameStyle,
    ansi.Style? keyStyle,
    ansi.Style? valueStyle,
    ansi.Style? unitsStyle,
    List<LogDepthTheme>? depthThemes,
    ansi.Style? stackTraceActiveStyle,
    ansi.Style? stackTraceInactiveStyle,
    Set<String>? tags = const {},
  })  : emphasis = emphasis ?? const ansi.NoStyle(),
        dim = dim ?? const ansi.NoStyle(),
        punctuation = punctuation ?? const ansi.NoStyle(),
        bold = bold ?? emphasis?.bold ?? const ansi.NoStyle(),
        inverse = inverse ??
            ansi.Style(
              foreground: _black,
              background: normal.foregroundColor,
            ),
        numStyle = numStyle ?? const ansi.NoStyle(),
        levelNameStyle = levelNameStyle ?? const ansi.NoStyle(),
        timeStyle = timeStyle ?? const ansi.NoStyle(),
        pathStyle = pathStyle ?? emphasis ?? const ansi.NoStyle(),
        messageStyles = messageStyles ?? defaultInactiveMessageStyles,
        controlCodesStyle =
            controlCodesStyle ?? punctuation ?? const ansi.NoStyle(),
        quotesStyle = quotesStyle ?? punctuation ?? const ansi.NoStyle(),
        colonStyle = colonStyle ?? punctuation ?? const ansi.NoStyle(),
        ellipsisStyle = ellipsisStyle ?? punctuation ?? const ansi.NoStyle(),
        lineBreakStyle = lineBreakStyle ?? punctuation ?? const ansi.NoStyle(),
        paddingStyle = paddingStyle ?? punctuation ?? const ansi.NoStyle(),
        sectionStyle =
            sectionStyle ?? bold ?? emphasis?.bold ?? const ansi.NoStyle(),
        nameStyle = nameStyle ?? const ansi.NoStyle(),
        keyStyle = keyStyle ?? emphasis ?? const ansi.NoStyle(),
        valueStyle = valueStyle ?? const ansi.NoStyle(),
        unitsStyle = unitsStyle ?? dim ?? const ansi.NoStyle(),
        depthThemes = depthThemes ??
            const [
              LogDepthTheme(
                brackets: ansi.NoStyle(),
                description: ansi.NoStyle(),
                punctuation: ansi.NoStyle(),
              ),
            ],
        stackTraceActiveStyle =
            stackTraceActiveStyle ?? emphasis ?? const ansi.NoStyle(),
        stackTraceInactiveStyle =
            stackTraceInactiveStyle ?? dim ?? const ansi.NoStyle(),
        tags = tags ?? const {};

  static const LogThemeData noColors = LogThemeData(
    normal: ansi.NoStyle(),
    inverse: ansi.NoStyle(),
    bold: ansi.NoStyle(),
    emphasis: ansi.NoStyle(),
    dim: ansi.NoStyle(),
    punctuation: ansi.NoStyle(),
    numStyle: ansi.NoStyle(),
    levelNameStyle: ansi.NoStyle(),
    timeStyle: ansi.NoStyle(),
    pathStyle: ansi.NoStyle(),
    messageStyles: defaultNoColorsMessageStyles,
    controlCodesStyle: ansi.NoStyle(),
    quotesStyle: ansi.NoStyle(),
    colonStyle: ansi.NoStyle(),
    ellipsisStyle: ansi.NoStyle(),
    lineBreakStyle: ansi.NoStyle(),
    paddingStyle: ansi.NoStyle(),
    sectionStyle: ansi.NoStyle(),
    nameStyle: ansi.NoStyle(),
    keyStyle: ansi.NoStyle(),
    valueStyle: ansi.NoStyle(),
    unitsStyle: ansi.NoStyle(),
    depthThemes: [LogDepthTheme.noStyle()],
    stackTraceActiveStyle: ansi.NoStyle(),
    stackTraceInactiveStyle: ansi.NoStyle(),
  );

  static const defaultMessageStyles = {
    'success': LogStyle(ansi.Styles.rgb050),
  };

  static const defaultMutedMessageStyles = {
    'success': LogStyle(ansi.Styles.rgb040),
  };

  static const defaultInactiveMessageStyles = {
    'success': LogStyle(ansi.Styles.rgb020),
  };

  static const Map<String, LogStyle> defaultNoColorsMessageStyles = {};

  static final gray5 = LogThemeData.seed(
    normal: ansi.Styles.gray5,
    emphasis: ansi.Styles.gray8,
    dim: ansi.Styles.gray3,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray6 = LogThemeData.seed(
    normal: ansi.Styles.gray6,
    emphasis: ansi.Styles.gray9,
    dim: ansi.Styles.gray4,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray7 = LogThemeData.seed(
    normal: ansi.Styles.gray7,
    emphasis: ansi.Styles.gray10,
    dim: ansi.Styles.gray5,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray8 = LogThemeData.seed(
    normal: ansi.Styles.gray8,
    emphasis: ansi.Styles.gray11,
    dim: ansi.Styles.gray6,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray9 = LogThemeData.seed(
    normal: ansi.Styles.gray9,
    emphasis: ansi.Styles.gray12,
    dim: ansi.Styles.gray7,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray10 = LogThemeData.seed(
    normal: ansi.Styles.gray10,
    emphasis: ansi.Styles.gray14,
    dim: ansi.Styles.gray7,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray11 = LogThemeData.seed(
    normal: ansi.Styles.gray11,
    emphasis: ansi.Styles.gray15,
    dim: ansi.Styles.gray8,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final gray12 = LogThemeData.seed(
    normal: ansi.Styles.gray12,
    emphasis: ansi.Styles.gray16,
    dim: ansi.Styles.gray9,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray13 = LogThemeData.seed(
    normal: ansi.Styles.gray13,
    emphasis: ansi.Styles.gray17,
    dim: ansi.Styles.gray10,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray14 = LogThemeData.seed(
    normal: ansi.Styles.gray14,
    emphasis: ansi.Styles.gray18,
    dim: ansi.Styles.gray11,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray15 = LogThemeData.seed(
    normal: ansi.Styles.gray15,
    emphasis: ansi.Styles.gray19,
    dim: ansi.Styles.gray12,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray16 = LogThemeData.seed(
    normal: ansi.Styles.gray16,
    emphasis: ansi.Styles.gray20,
    dim: ansi.Styles.gray13,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray17 = LogThemeData.seed(
    normal: ansi.Styles.gray17,
    emphasis: ansi.Styles.gray22,
    dim: ansi.Styles.gray13,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray18 = LogThemeData.seed(
    normal: ansi.Styles.gray18,
    emphasis: ansi.Styles.gray23,
    dim: ansi.Styles.gray14,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray19 = LogThemeData.seed(
    normal: ansi.Styles.gray19,
    emphasis: ansi.Styles.gray23,
    dim: ansi.Styles.gray15,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final gray20 = LogThemeData.seed(
    normal: ansi.Styles.gray20,
    emphasis: ansi.Styles.gray23,
    dim: ansi.Styles.gray16,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final rgb444 = LogThemeData.seed(
    normal: ansi.Styles.rgb444,
    emphasis: ansi.Styles.rgb555,
    dim: ansi.Styles.rgb333,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final rgb443 = LogThemeData.seed(
    normal: ansi.Styles.rgb443,
    emphasis: ansi.Styles.rgb554,
    dim: ansi.Styles.rgb332,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb442 = LogThemeData.seed(
    normal: ansi.Styles.rgb442,
    emphasis: ansi.Styles.rgb553,
    dim: ansi.Styles.rgb331,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb441 = LogThemeData.seed(
    normal: ansi.Styles.rgb441,
    emphasis: ansi.Styles.rgb552,
    dim: ansi.Styles.rgb330,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb440 = LogThemeData.seed(
    normal: ansi.Styles.rgb440,
    emphasis: ansi.Styles.rgb550,
    dim: ansi.Styles.rgb330,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb434 = LogThemeData.seed(
    normal: ansi.Styles.rgb434,
    emphasis: ansi.Styles.rgb545,
    dim: ansi.Styles.rgb323,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb433 = LogThemeData.seed(
    normal: ansi.Styles.rgb433,
    emphasis: ansi.Styles.rgb544,
    dim: ansi.Styles.rgb322,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb432 = LogThemeData.seed(
    normal: ansi.Styles.rgb432,
    emphasis: ansi.Styles.rgb543,
    dim: ansi.Styles.rgb321,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb431 = LogThemeData.seed(
    normal: ansi.Styles.rgb431,
    emphasis: ansi.Styles.rgb542,
    dim: ansi.Styles.rgb320,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb430 = LogThemeData.seed(
    normal: ansi.Styles.rgb430,
    emphasis: ansi.Styles.rgb540,
    dim: ansi.Styles.rgb320,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb424 = LogThemeData.seed(
    normal: ansi.Styles.rgb424,
    emphasis: ansi.Styles.rgb535,
    dim: ansi.Styles.rgb313,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb423 = LogThemeData.seed(
    normal: ansi.Styles.rgb423,
    emphasis: ansi.Styles.rgb534,
    dim: ansi.Styles.rgb312,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb422 = LogThemeData.seed(
    normal: ansi.Styles.rgb422,
    emphasis: ansi.Styles.rgb533,
    dim: ansi.Styles.rgb311,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb421 = LogThemeData.seed(
    normal: ansi.Styles.rgb421,
    emphasis: ansi.Styles.rgb532,
    dim: ansi.Styles.rgb310,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb420 = LogThemeData.seed(
    normal: ansi.Styles.rgb420,
    emphasis: ansi.Styles.rgb530,
    dim: ansi.Styles.rgb310,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb414 = LogThemeData.seed(
    normal: ansi.Styles.rgb414,
    emphasis: ansi.Styles.rgb525,
    dim: ansi.Styles.rgb303,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb413 = LogThemeData.seed(
    normal: ansi.Styles.rgb413,
    emphasis: ansi.Styles.rgb524,
    dim: ansi.Styles.rgb302,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb412 = LogThemeData.seed(
    normal: ansi.Styles.rgb412,
    emphasis: ansi.Styles.rgb523,
    dim: ansi.Styles.rgb301,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb411 = LogThemeData.seed(
    normal: ansi.Styles.rgb411,
    emphasis: ansi.Styles.rgb522,
    dim: ansi.Styles.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb410 = LogThemeData.seed(
    normal: ansi.Styles.rgb410,
    emphasis: ansi.Styles.rgb520,
    dim: ansi.Styles.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb404 = LogThemeData.seed(
    normal: ansi.Styles.rgb404,
    emphasis: ansi.Styles.rgb505,
    dim: ansi.Styles.rgb303,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb403 = LogThemeData.seed(
    normal: ansi.Styles.rgb403,
    emphasis: ansi.Styles.rgb504,
    dim: ansi.Styles.rgb302,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb402 = LogThemeData.seed(
    normal: ansi.Styles.rgb402,
    emphasis: ansi.Styles.rgb503,
    dim: ansi.Styles.rgb301,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb401 = LogThemeData.seed(
    normal: ansi.Styles.rgb401,
    emphasis: ansi.Styles.rgb502,
    dim: ansi.Styles.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb400 = LogThemeData.seed(
    normal: ansi.Styles.rgb400,
    emphasis: ansi.Styles.rgb500,
    dim: ansi.Styles.rgb300,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb344 = LogThemeData.seed(
    normal: ansi.Styles.rgb344,
    emphasis: ansi.Styles.rgb455,
    dim: ansi.Styles.rgb233,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb343 = LogThemeData.seed(
    normal: ansi.Styles.rgb343,
    emphasis: ansi.Styles.rgb454,
    dim: ansi.Styles.rgb232,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb342 = LogThemeData.seed(
    normal: ansi.Styles.rgb342,
    emphasis: ansi.Styles.rgb453,
    dim: ansi.Styles.rgb231,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb341 = LogThemeData.seed(
    normal: ansi.Styles.rgb341,
    emphasis: ansi.Styles.rgb452,
    dim: ansi.Styles.rgb230,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb340 = LogThemeData.seed(
    normal: ansi.Styles.rgb340,
    emphasis: ansi.Styles.rgb450,
    dim: ansi.Styles.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb334 = LogThemeData.seed(
    normal: ansi.Styles.rgb334,
    emphasis: ansi.Styles.rgb445,
    dim: ansi.Styles.rgb223,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb333 = LogThemeData.seed(
    normal: ansi.Styles.rgb333,
    emphasis: ansi.Styles.rgb444,
    dim: ansi.Styles.rgb222,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final rgb332 = LogThemeData.seed(
    normal: ansi.Styles.rgb332,
    emphasis: ansi.Styles.rgb443,
    dim: ansi.Styles.rgb221,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb331 = LogThemeData.seed(
    normal: ansi.Styles.rgb331,
    emphasis: ansi.Styles.rgb442,
    dim: ansi.Styles.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb330 = LogThemeData.seed(
    normal: ansi.Styles.rgb330,
    emphasis: ansi.Styles.rgb440,
    dim: ansi.Styles.rgb220,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb324 = LogThemeData.seed(
    normal: ansi.Styles.rgb324,
    emphasis: ansi.Styles.rgb435,
    dim: ansi.Styles.rgb213,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb323 = LogThemeData.seed(
    normal: ansi.Styles.rgb323,
    emphasis: ansi.Styles.rgb434,
    dim: ansi.Styles.rgb212,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb322 = LogThemeData.seed(
    normal: ansi.Styles.rgb322,
    emphasis: ansi.Styles.rgb433,
    dim: ansi.Styles.rgb211,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb321 = LogThemeData.seed(
    normal: ansi.Styles.rgb321,
    emphasis: ansi.Styles.rgb432,
    dim: ansi.Styles.rgb210,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoOrangeAndRed,
  );

  static final rgb320 = LogThemeData.seed(
    normal: ansi.Styles.rgb320,
    emphasis: ansi.Styles.rgb430,
    dim: ansi.Styles.rgb210,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndOrange,
  );

  static final rgb314 = LogThemeData.seed(
    normal: ansi.Styles.rgb314,
    emphasis: ansi.Styles.rgb425,
    dim: ansi.Styles.rgb203,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb313 = LogThemeData.seed(
    normal: ansi.Styles.rgb313,
    emphasis: ansi.Styles.rgb424,
    dim: ansi.Styles.rgb202,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb312 = LogThemeData.seed(
    normal: ansi.Styles.rgb312,
    emphasis: ansi.Styles.rgb423,
    dim: ansi.Styles.rgb201,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb311 = LogThemeData.seed(
    normal: ansi.Styles.rgb311,
    emphasis: ansi.Styles.rgb422,
    dim: ansi.Styles.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb310 = LogThemeData.seed(
    normal: ansi.Styles.rgb310,
    emphasis: ansi.Styles.rgb420,
    dim: ansi.Styles.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb304 = LogThemeData.seed(
    normal: ansi.Styles.rgb304,
    emphasis: ansi.Styles.rgb405,
    dim: ansi.Styles.rgb203,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoMagentaAndRed,
  );

  static final rgb303 = LogThemeData.seed(
    normal: ansi.Styles.rgb303,
    emphasis: ansi.Styles.rgb404,
    dim: ansi.Styles.rgb202,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb302 = LogThemeData.seed(
    normal: ansi.Styles.rgb302,
    emphasis: ansi.Styles.rgb403,
    dim: ansi.Styles.rgb201,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb301 = LogThemeData.seed(
    normal: ansi.Styles.rgb301,
    emphasis: ansi.Styles.rgb402,
    dim: ansi.Styles.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb300 = LogThemeData.seed(
    normal: ansi.Styles.rgb300,
    emphasis: ansi.Styles.rgb400,
    dim: ansi.Styles.rgb200,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb244 = LogThemeData.seed(
    normal: ansi.Styles.rgb244,
    emphasis: ansi.Styles.rgb355,
    dim: ansi.Styles.rgb133,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb243 = LogThemeData.seed(
    normal: ansi.Styles.rgb243,
    emphasis: ansi.Styles.rgb354,
    dim: ansi.Styles.rgb132,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb242 = LogThemeData.seed(
    normal: ansi.Styles.rgb242,
    emphasis: ansi.Styles.rgb353,
    dim: ansi.Styles.rgb131,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb241 = LogThemeData.seed(
    normal: ansi.Styles.rgb241,
    emphasis: ansi.Styles.rgb352,
    dim: ansi.Styles.rgb130,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb240 = LogThemeData.seed(
    normal: ansi.Styles.rgb240,
    emphasis: ansi.Styles.rgb350,
    dim: ansi.Styles.rgb130,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb234 = LogThemeData.seed(
    normal: ansi.Styles.rgb234,
    emphasis: ansi.Styles.rgb345,
    dim: ansi.Styles.rgb123,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb233 = LogThemeData.seed(
    normal: ansi.Styles.rgb233,
    emphasis: ansi.Styles.rgb344,
    dim: ansi.Styles.rgb122,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb232 = LogThemeData.seed(
    normal: ansi.Styles.rgb232,
    emphasis: ansi.Styles.rgb343,
    dim: ansi.Styles.rgb121,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb231 = LogThemeData.seed(
    normal: ansi.Styles.rgb231,
    emphasis: ansi.Styles.rgb342,
    dim: ansi.Styles.rgb120,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb230 = LogThemeData.seed(
    normal: ansi.Styles.rgb230,
    emphasis: ansi.Styles.rgb340,
    dim: ansi.Styles.rgb120,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb224 = LogThemeData.seed(
    normal: ansi.Styles.rgb224,
    emphasis: ansi.Styles.rgb335,
    dim: ansi.Styles.rgb113,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb223 = LogThemeData.seed(
    normal: ansi.Styles.rgb223,
    emphasis: ansi.Styles.rgb334,
    dim: ansi.Styles.rgb112,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb222 = LogThemeData.seed(
    normal: ansi.Styles.rgb222,
    emphasis: ansi.Styles.rgb333,
    dim: ansi.Styles.rgb111,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoGreenAndRed,
  );

  static final rgb221 = LogThemeData.seed(
    normal: ansi.Styles.rgb221,
    emphasis: ansi.Styles.rgb332,
    dim: ansi.Styles.rgb110,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb220 = LogThemeData.seed(
    normal: ansi.Styles.rgb220,
    emphasis: ansi.Styles.rgb330,
    dim: ansi.Styles.rgb110,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb214 = LogThemeData.seed(
    normal: ansi.Styles.rgb214,
    emphasis: ansi.Styles.rgb325,
    dim: ansi.Styles.rgb103,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb213 = LogThemeData.seed(
    normal: ansi.Styles.rgb213,
    emphasis: ansi.Styles.rgb324,
    dim: ansi.Styles.rgb102,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb212 = LogThemeData.seed(
    normal: ansi.Styles.rgb212,
    emphasis: ansi.Styles.rgb323,
    dim: ansi.Styles.rgb101,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb211 = LogThemeData.seed(
    normal: ansi.Styles.rgb211,
    emphasis: ansi.Styles.rgb322,
    dim: ansi.Styles.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb210 = LogThemeData.seed(
    normal: ansi.Styles.rgb210,
    emphasis: ansi.Styles.rgb320,
    dim: ansi.Styles.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndOrange,
  );

  static final rgb204 = LogThemeData.seed(
    normal: ansi.Styles.rgb204,
    emphasis: ansi.Styles.rgb305,
    dim: ansi.Styles.rgb103,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb203 = LogThemeData.seed(
    normal: ansi.Styles.rgb203,
    emphasis: ansi.Styles.rgb304,
    dim: ansi.Styles.rgb102,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb202 = LogThemeData.seed(
    normal: ansi.Styles.rgb202,
    emphasis: ansi.Styles.rgb303,
    dim: ansi.Styles.rgb101,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb201 = LogThemeData.seed(
    normal: ansi.Styles.rgb201,
    emphasis: ansi.Styles.rgb302,
    dim: ansi.Styles.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoMagentaAndRed,
  );

  static final rgb200 = LogThemeData.seed(
    normal: ansi.Styles.rgb200,
    emphasis: ansi.Styles.rgb300,
    dim: ansi.Styles.rgb100,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoOrangeAndRed,
  );

  static final rgb144 = LogThemeData.seed(
    normal: ansi.Styles.rgb144,
    emphasis: ansi.Styles.rgb255,
    dim: ansi.Styles.rgb033,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb143 = LogThemeData.seed(
    normal: ansi.Styles.rgb143,
    emphasis: ansi.Styles.rgb254,
    dim: ansi.Styles.rgb032,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final rgb142 = LogThemeData.seed(
    normal: ansi.Styles.rgb142,
    emphasis: ansi.Styles.rgb253,
    dim: ansi.Styles.rgb031,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb141 = LogThemeData.seed(
    normal: ansi.Styles.rgb141,
    emphasis: ansi.Styles.rgb252,
    dim: ansi.Styles.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb140 = LogThemeData.seed(
    normal: ansi.Styles.rgb140,
    emphasis: ansi.Styles.rgb250,
    dim: ansi.Styles.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb134 = LogThemeData.seed(
    normal: ansi.Styles.rgb134,
    emphasis: ansi.Styles.rgb245,
    dim: ansi.Styles.rgb023,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb133 = LogThemeData.seed(
    normal: ansi.Styles.rgb133,
    emphasis: ansi.Styles.rgb244,
    dim: ansi.Styles.rgb022,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb132 = LogThemeData.seed(
    normal: ansi.Styles.rgb132,
    emphasis: ansi.Styles.rgb243,
    dim: ansi.Styles.rgb021,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoGreenAndRed,
  );

  static final rgb131 = LogThemeData.seed(
    normal: ansi.Styles.rgb131,
    emphasis: ansi.Styles.rgb242,
    dim: ansi.Styles.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb130 = LogThemeData.seed(
    normal: ansi.Styles.rgb130,
    emphasis: ansi.Styles.rgb240,
    dim: ansi.Styles.rgb020,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb124 = LogThemeData.seed(
    normal: ansi.Styles.rgb124,
    emphasis: ansi.Styles.rgb235,
    dim: ansi.Styles.rgb013,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb123 = LogThemeData.seed(
    normal: ansi.Styles.rgb123,
    emphasis: ansi.Styles.rgb234,
    dim: ansi.Styles.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb122 = LogThemeData.seed(
    normal: ansi.Styles.rgb122,
    emphasis: ansi.Styles.rgb233,
    dim: ansi.Styles.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndGreen,
  );

  static final rgb121 = LogThemeData.seed(
    normal: ansi.Styles.rgb121,
    emphasis: ansi.Styles.rgb232,
    dim: ansi.Styles.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb120 = LogThemeData.seed(
    normal: ansi.Styles.rgb120,
    emphasis: ansi.Styles.rgb230,
    dim: ansi.Styles.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb114 = LogThemeData.seed(
    normal: ansi.Styles.rgb114,
    emphasis: ansi.Styles.rgb225,
    dim: ansi.Styles.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb113 = LogThemeData.seed(
    normal: ansi.Styles.rgb113,
    emphasis: ansi.Styles.rgb224,
    dim: ansi.Styles.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb112 = LogThemeData.seed(
    normal: ansi.Styles.rgb112,
    emphasis: ansi.Styles.rgb223,
    dim: ansi.Styles.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb104 = LogThemeData.seed(
    normal: ansi.Styles.rgb104,
    emphasis: ansi.Styles.rgb205,
    dim: ansi.Styles.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb103 = LogThemeData.seed(
    normal: ansi.Styles.rgb103,
    emphasis: ansi.Styles.rgb204,
    dim: ansi.Styles.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb102 = LogThemeData.seed(
    normal: ansi.Styles.rgb102,
    emphasis: ansi.Styles.rgb203,
    dim: ansi.Styles.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndMagenta,
  );

  static final rgb044 = LogThemeData.seed(
    normal: ansi.Styles.rgb044,
    emphasis: ansi.Styles.rgb055,
    dim: ansi.Styles.rgb033,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb043 = LogThemeData.seed(
    normal: ansi.Styles.rgb043,
    emphasis: ansi.Styles.rgb054,
    dim: ansi.Styles.rgb032,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb042 = LogThemeData.seed(
    normal: ansi.Styles.rgb042,
    emphasis: ansi.Styles.rgb053,
    dim: ansi.Styles.rgb031,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb041 = LogThemeData.seed(
    normal: ansi.Styles.rgb041,
    emphasis: ansi.Styles.rgb050,
    dim: ansi.Styles.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb040 = LogThemeData.seed(
    normal: ansi.Styles.rgb040,
    emphasis: ansi.Styles.rgb050,
    dim: ansi.Styles.rgb030,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb034 = LogThemeData.seed(
    normal: ansi.Styles.rgb034,
    emphasis: ansi.Styles.rgb045,
    dim: ansi.Styles.rgb023,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndRed,
  );

  static final rgb033 = LogThemeData.seed(
    normal: ansi.Styles.rgb033,
    emphasis: ansi.Styles.rgb044,
    dim: ansi.Styles.rgb022,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb032 = LogThemeData.seed(
    normal: ansi.Styles.rgb032,
    emphasis: ansi.Styles.rgb043,
    dim: ansi.Styles.rgb021,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoBlueAndGreen,
  );

  static final rgb031 = LogThemeData.seed(
    normal: ansi.Styles.rgb031,
    emphasis: ansi.Styles.rgb042,
    dim: ansi.Styles.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb030 = LogThemeData.seed(
    normal: ansi.Styles.rgb030,
    emphasis: ansi.Styles.rgb040,
    dim: ansi.Styles.rgb020,
    messageStyles: defaultMessageStyles,
    punctuation: defaultPunctuation,
    depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
  );

  static final rgb024 = LogThemeData.seed(
    normal: ansi.Styles.rgb024,
    emphasis: ansi.Styles.rgb035,
    dim: ansi.Styles.rgb013,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb023 = LogThemeData.seed(
    normal: ansi.Styles.rgb023,
    emphasis: ansi.Styles.rgb034,
    dim: ansi.Styles.rgb012,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb022 = LogThemeData.seed(
    normal: ansi.Styles.rgb022,
    emphasis: ansi.Styles.rgb033,
    dim: ansi.Styles.rgb011,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndGreen,
  );

  static final rgb021 = LogThemeData.seed(
    normal: ansi.Styles.rgb021,
    emphasis: ansi.Styles.rgb032,
    dim: ansi.Styles.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb020 = LogThemeData.seed(
    normal: ansi.Styles.rgb020,
    emphasis: ansi.Styles.rgb030,
    dim: ansi.Styles.rgb010,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoYellowAndGreen,
  );

  static final rgb014 = LogThemeData.seed(
    normal: ansi.Styles.rgb014,
    emphasis: ansi.Styles.rgb025,
    dim: ansi.Styles.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb013 = LogThemeData.seed(
    normal: ansi.Styles.rgb013,
    emphasis: ansi.Styles.rgb024,
    dim: ansi.Styles.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb012 = LogThemeData.seed(
    normal: ansi.Styles.rgb012,
    emphasis: ansi.Styles.rgb023,
    dim: ansi.Styles.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb004 = LogThemeData.seed(
    normal: ansi.Styles.rgb004,
    emphasis: ansi.Styles.rgb005,
    dim: ansi.Styles.rgb003,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb003 = LogThemeData.seed(
    normal: ansi.Styles.rgb003,
    emphasis: ansi.Styles.rgb004,
    dim: ansi.Styles.rgb002,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static final rgb002 = LogThemeData.seed(
    normal: ansi.Styles.rgb002,
    emphasis: ansi.Styles.rgb003,
    dim: ansi.Styles.rgb001,
    messageStyles: defaultMutedMessageStyles,
    punctuation: defaultMutedPunctuation,
    depthThemes: LogDepthTheme.defaultMutedThemesWoBlueAndRed,
  );

  static const defaultPunctuation = ansi.Styles.rgb044;

  static const defaultMutedPunctuation = ansi.Styles.rgb033;

  static const _black = ansi.Color256.gray0;

  LogThemeData copyWith({
    ansi.Style? normal,
    ansi.Style? inverse,
    ansi.Style? bold,
    ansi.Style? emphasis,
    ansi.Style? dim,
    ansi.Style? numStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    Map<String, LogStyle>? messageStyles,
    ansi.Style? controlCodesStyle,
    ansi.Style? punctuation,
    ansi.Style? quotesStyle,
    ansi.Style? colonStyle,
    ansi.Style? ellipsisStyle,
    ansi.Style? lineBreakStyle,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    ansi.Style? nameStyle,
    ansi.Style? keyStyle,
    ansi.Style? valueStyle,
    ansi.Style? unitsStyle,
    List<LogDepthTheme>? depthThemes,
    ansi.Style? stackTraceActiveStyle,
    ansi.Style? stackTraceInactiveStyle,
    Set<String>? tags,
  }) =>
      LogThemeData(
        normal: normal ?? this.normal,
        inverse: inverse ?? this.inverse,
        bold: bold ?? this.bold,
        emphasis: emphasis ?? this.emphasis,
        dim: dim ?? this.dim,
        numStyle: numStyle ?? this.numStyle,
        levelNameStyle: levelNameStyle ?? this.levelNameStyle,
        timeStyle: timeStyle ?? this.timeStyle,
        pathStyle: pathStyle ?? this.pathStyle,
        messageStyles: messageStyles ?? this.messageStyles,
        controlCodesStyle: controlCodesStyle ?? this.controlCodesStyle,
        punctuation: punctuation ?? this.punctuation,
        quotesStyle: quotesStyle ?? this.quotesStyle,
        colonStyle: colonStyle ?? this.colonStyle,
        ellipsisStyle: ellipsisStyle ?? this.ellipsisStyle,
        lineBreakStyle: lineBreakStyle ?? this.lineBreakStyle,
        paddingStyle: paddingStyle ?? this.paddingStyle,
        sectionStyle: sectionStyle ?? this.sectionStyle,
        nameStyle: nameStyle ?? this.nameStyle,
        keyStyle: keyStyle ?? this.keyStyle,
        valueStyle: valueStyle ?? this.valueStyle,
        unitsStyle: unitsStyle ?? this.unitsStyle,
        depthThemes: depthThemes ?? this.depthThemes,
        stackTraceActiveStyle:
            stackTraceActiveStyle ?? this.stackTraceActiveStyle,
        stackTraceInactiveStyle:
            stackTraceInactiveStyle ?? this.stackTraceInactiveStyle,
        tags: tags ?? this.tags,
      );

  LogThemeData copyWithMainStyles({
    required ansi.Style normal,
    ansi.Style? inverse,
    required ansi.Style emphasis,
    ansi.Style? bold,
    required ansi.Style dim,
    List<LogDepthTheme>? depthThemes,
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
      sectionStyle: bold,
      keyStyle: emphasis,
      unitsStyle: dim,
      depthThemes: depthThemes,
      stackTraceActiveStyle: emphasis,
      stackTraceInactiveStyle: dim,
    );
  }

  LogThemeData copyWithPunctuation(
    ansi.Style punctuation, {
    bool setForControlCodes = true,
    bool setForQuotes = true,
    bool setForColon = true,
    bool setForEllipsis = true,
    bool setForLineBreak = true,
    bool setForPadding = true,
  }) =>
      copyWith(
        punctuation: punctuation,
        controlCodesStyle: setForControlCodes ? punctuation : null,
        quotesStyle: setForQuotes ? punctuation : null,
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
      ..style('numStyle', this, numStyle)
      ..style('levelNameStyle', this, levelNameStyle)
      ..style('timeStyle', this, timeStyle)
      ..style('pathStyle', this, pathStyle)
      ..lazyStyles('messageStyles', messageStyles)
      ..style('controlCodesStyle', this, controlCodesStyle)
      ..style('quotesStyle', this, quotesStyle)
      ..style('colonStyle', this, colonStyle)
      ..style('ellipsisStyle', this, ellipsisStyle)
      ..style('lineBreakStyle', this, lineBreakStyle)
      ..style('paddingStyle', this, paddingStyle)
      ..style('sectionStyle', this, sectionStyle)
      ..style('nameStyle', this, nameStyle)
      ..style('keyStyle', this, keyStyle)
      ..style('valueStyle', this, valueStyle)
      ..style('unitsStyle', this, unitsStyle)
      ..depthThemes('depthThemes', depthThemes)
      ..style('stackTraceActiveStyle', this, stackTraceActiveStyle)
      ..style('stackTraceInactiveStyle', this, stackTraceInactiveStyle)
      ..prop('tags', tags);
  }
}

final class LogDepthTheme {
  final ansi.Style brackets;
  final ansi.Style punctuation;
  final ansi.Style description;

  const LogDepthTheme({
    required this.brackets,
    required this.punctuation,
    required this.description,
  });

  const LogDepthTheme.noStyle()
      : brackets = const ansi.NoStyle(),
        punctuation = const ansi.NoStyle(),
        description = const ansi.NoStyle();

  static const red = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb511, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb511),
    description: ansi.Style(foreground: ansi.Color256.rgb400),
  );

  static const mutedRed = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb410, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb410),
    description: ansi.Style(foreground: ansi.Color256.rgb300),
  );

  static const orange = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb530, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb530),
    description: ansi.Style(foreground: ansi.Color256.rgb420),
  );

  static const mutedOrange = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb420, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb420),
    description: ansi.Style(foreground: ansi.Color256.rgb310),
  );

  static const yellow = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb550, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb550),
    description: ansi.Style(foreground: ansi.Color256.rgb440),
  );

  static const mutedYellow = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb440, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb440),
    description: ansi.Style(foreground: ansi.Color256.rgb330),
  );

  static const green = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb051, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb051),
    description: ansi.Style(foreground: ansi.Color256.rgb040),
  );

  static const mutedGreen = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb040, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb040),
    description: ansi.Style(foreground: ansi.Color256.rgb030),
  );

  static const blue = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb035, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb035),
    description: ansi.Style(foreground: ansi.Color256.rgb024),
  );

  static const mutedBlue = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb024, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb024),
    description: ansi.Style(foreground: ansi.Color256.rgb013),
  );

  static const magenta = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb515, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb515),
    description: ansi.Style(foreground: ansi.Color256.rgb404),
  );

  static const mutedMagenta = LogDepthTheme(
    brackets: ansi.Style(foreground: ansi.Color256.rgb404, bold: true),
    punctuation: ansi.Style(foreground: ansi.Color256.rgb404),
    description: ansi.Style(foreground: ansi.Color256.rgb303),
  );

  static const defaultThemesWoBlueAndMagenta = [
    LogDepthTheme.yellow,
    LogDepthTheme.green,
    LogDepthTheme.orange,
    LogDepthTheme.red,
  ];

  static const defaultMutedThemesWoBlueAndMagenta = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedRed,
  ];

  static const defaultThemesWoBlueAndRed = [
    LogDepthTheme.yellow,
    LogDepthTheme.green,
    LogDepthTheme.orange,
    LogDepthTheme.magenta,
  ];

  static const defaultMutedThemesWoBlueAndRed = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedMagenta,
  ];

  static const defaultThemesWoBlueAndGreen = [
    LogDepthTheme.yellow,
    LogDepthTheme.orange,
    LogDepthTheme.magenta,
    LogDepthTheme.red,
  ];

  static const defaultMutedThemesWoBlueAndGreen = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedMagenta,
    LogDepthTheme.mutedRed,
  ];

  static const defaultThemesWoGreenAndRed = [
    LogDepthTheme.yellow,
    LogDepthTheme.blue,
    LogDepthTheme.orange,
    LogDepthTheme.magenta,
  ];

  static const defaultMutedThemesWoGreenAndRed = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedMagenta,
  ];

  static const defaultThemesWoYellowAndGreen = [
    LogDepthTheme.blue,
    LogDepthTheme.orange,
    LogDepthTheme.magenta,
    LogDepthTheme.red,
  ];

  static const defaultMutedThemesWoYellowAndGreen = [
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedMagenta,
    LogDepthTheme.mutedRed,
  ];

  static const defaultThemesWoYellowAndOrange = [
    LogDepthTheme.blue,
    LogDepthTheme.green,
    LogDepthTheme.magenta,
    LogDepthTheme.red,
  ];

  static const defaultMutedThemesWoYellowAndOrange = [
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedMagenta,
    LogDepthTheme.mutedRed,
  ];

  static const defaultThemesWoYellowAndRed = [
    LogDepthTheme.blue,
    LogDepthTheme.green,
    LogDepthTheme.orange,
    LogDepthTheme.magenta,
  ];

  static const defaultMutedThemesWoYellowAndRed = [
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedOrange,
    LogDepthTheme.mutedMagenta,
  ];

  static const defaultThemesWoOrangeAndRed = [
    LogDepthTheme.yellow,
    LogDepthTheme.blue,
    LogDepthTheme.green,
    LogDepthTheme.magenta,
  ];

  static const defaultMutedThemesWoOrangeAndRed = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedMagenta,
  ];

  static const defaultThemesWoOrangeAndMagenta = [
    LogDepthTheme.yellow,
    LogDepthTheme.blue,
    LogDepthTheme.green,
    LogDepthTheme.red,
  ];

  static const defaultMutedThemesWoOrangeAndMagenta = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedRed,
  ];

  static const defaultThemesWoMagentaAndRed = [
    LogDepthTheme.yellow,
    LogDepthTheme.blue,
    LogDepthTheme.green,
    LogDepthTheme.orange,
  ];

  static const defaultMutedThemesWoMagentaAndRed = [
    LogDepthTheme.mutedYellow,
    LogDepthTheme.mutedBlue,
    LogDepthTheme.mutedGreen,
    LogDepthTheme.mutedOrange,
  ];
}

extension on LoggableData {
  void theme(String name, LogThemeData theme) {
    prop(name, theme, showName: false, view: theme.normal(name));
  }

  void style(
    String name,
    LogThemeData? theme,
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

  void depthThemes(String name, List<LogDepthTheme> styles) {
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

  void lazyStyles(String name, Map<String, LogStyle> styles) {
    final mapBuilder = Loggable.mapBuilder();
    for (final MapEntry(:key, value: style) in styles.entries) {
      mapBuilder.prop(
        key,
        style,
        showName: false,
        view: switch (style) {
          _LogStyle(:final style) => style(key),
          LogLazyStyle(:final call) =>
            LoggableView.convert((_, theme, __) => call(theme)(key)),
        },
      );
    }

    prop(name, mapBuilder);
  }
}
