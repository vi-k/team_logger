part of 'log_theme.dart';

final class LogLevelTheme with Loggable {
  static final _mainThemeExpando = Expando<LogTheme>();

  final ansi.Style normalStyle;
  final ansi.Style boldStyle;
  final ansi.Style dimStyle;
  final ansi.Style superDimStyle;
  final ansi.Style sequenceNumStyle;
  final ansi.Style levelNameStyle;
  final ansi.Style timeStyle;
  final ansi.Style pathStyle;
  final Map<String, ansi.Style> messageStyles;
  final LogPreFormatter valueFormatter;
  final LogPreFormatter messageFormatter;
  final ansi.Style tagsStyle;
  final ansi.Style controlCodesStyle;
  final ansi.Style punctuationStyle;
  final ansi.Style colonStyle;
  final ansi.Style ellipsisStyle;
  final ansi.Style lineBreakStyle;
  final ansi.Style paddingStyle;
  final ansi.Style dataSectionStyle;
  final ansi.Style dataNameStyle;
  final ansi.Style dataKeyStyle;
  final ansi.Style dataValueStyle;
  final ansi.Style dataUnitsStyle;
  final List<ansi.Style> dataBracketsStyles;
  final List<ansi.Style> dataDescriptionStyles;
  final List<ansi.Style> dataPunctuationStyles;
  final Set<String> tags;

  LogLevelTheme({
    this.normalStyle = ansi.Style.terminalColors,
    ansi.Style? boldStyle,
    ansi.Style? dimStyle,
    ansi.Style? superDimStyle,
    ansi.Style? sequenceNumStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    this.messageStyles = const {},
    this.valueFormatter = const ControlCodeFormatter(),
    this.messageFormatter = const BbCodeFormatter(),
    ansi.Style? tagsStyle,
    ansi.Style? controlCodesStyle,
    ansi.Style? punctuationStyle,
    ansi.Style? colonStyle,
    ansi.Style? ellipsisStyle,
    ansi.Style? lineBreakStyle,
    ansi.Style? paddingStyle,
    ansi.Style? sectionStyle,
    ansi.Style? nameStyle,
    ansi.Style? keyStyles,
    ansi.Style? valueStyles,
    ansi.Style? unitsStyles,
    List<ansi.Style>? bracketsStyles,
    List<ansi.Style>? descriptionStyles,
    List<ansi.Style>? punctuationStyles,
    this.tags = const {},
  })  : boldStyle = boldStyle ?? normalStyle.bold,
        dimStyle = dimStyle ?? normalStyle.dim,
        superDimStyle = superDimStyle ?? normalStyle,
        sequenceNumStyle = sequenceNumStyle ?? const ansi.NoStyle(),
        levelNameStyle = levelNameStyle ??
            (normalStyle.foregroundColor == null
                ? const ansi.NoStyle()
                : ansi.Style(
                    background: normalStyle.foregroundColor,
                    foreground: LogTheme._black,
                  )),
        timeStyle = timeStyle ?? const ansi.NoStyle(),
        pathStyle = pathStyle ?? const ansi.NoStyle(),
        tagsStyle = tagsStyle ?? const ansi.NoStyle(),
        controlCodesStyle = controlCodesStyle ?? const ansi.NoStyle(),
        punctuationStyle = punctuationStyle ?? const ansi.NoStyle(),
        colonStyle = colonStyle ?? punctuationStyle ?? const ansi.NoStyle(),
        ellipsisStyle =
            ellipsisStyle ?? punctuationStyle ?? const ansi.NoStyle(),
        lineBreakStyle =
            lineBreakStyle ?? punctuationStyle ?? const ansi.NoStyle(),
        paddingStyle = paddingStyle ?? punctuationStyle ?? const ansi.NoStyle(),
        dataSectionStyle = sectionStyle ?? const ansi.NoStyle(),
        dataNameStyle = nameStyle ?? const ansi.NoStyle(),
        dataKeyStyle = keyStyles ?? const ansi.NoStyle(),
        dataValueStyle = valueStyles ?? const ansi.NoStyle(),
        dataUnitsStyle = unitsStyles ?? const ansi.NoStyle(),
        assert(bracketsStyles == null || bracketsStyles.isNotEmpty),
        assert(descriptionStyles == null || descriptionStyles.isNotEmpty),
        assert(punctuationStyles == null || punctuationStyles.isNotEmpty),
        assert(bracketsStyles?.length == descriptionStyles?.length),
        assert(descriptionStyles?.length == punctuationStyles?.length),
        dataBracketsStyles = bracketsStyles ?? [const ansi.NoStyle()],
        dataDescriptionStyles = descriptionStyles ?? [const ansi.NoStyle()],
        dataPunctuationStyles = punctuationStyles ?? [const ansi.NoStyle()];

  const LogLevelTheme._({
    required this.normalStyle,
    required this.boldStyle,
    required this.dimStyle,
    required this.superDimStyle,
    required this.sequenceNumStyle,
    required this.levelNameStyle,
    required this.timeStyle,
    required this.pathStyle,
    required this.messageStyles,
    required this.valueFormatter,
    required this.messageFormatter,
    required this.tagsStyle,
    required this.controlCodesStyle,
    required this.punctuationStyle,
    required this.colonStyle,
    required this.ellipsisStyle,
    required this.lineBreakStyle,
    required this.paddingStyle,
    required this.dataSectionStyle,
    required this.dataNameStyle,
    required this.dataKeyStyle,
    required this.dataValueStyle,
    required this.dataUnitsStyle,
    required this.dataBracketsStyles,
    required this.dataDescriptionStyles,
    required this.dataPunctuationStyles,
    this.tags = const {},
  });

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

  ansi.Style dataBracketsStyle(int level) =>
      dataBracketsStyles[level % dataBracketsStyles.length];

  ansi.Style dataDescriptionStyle(int level) =>
      dataDescriptionStyles[level % dataDescriptionStyles.length];

  ansi.Style dataPunctuationStyle(int level) =>
      dataPunctuationStyles[level % dataPunctuationStyles.length];

  Set<String> allTags(Log log) => {
        ...common.tags,
        ...tags,
        ...log.tags,
      };

  static const LogLevelTheme noColors = LogLevelTheme._(
    normalStyle: ansi.NoStyle(),
    boldStyle: ansi.NoStyle(),
    dimStyle: ansi.NoStyle(),
    superDimStyle: ansi.NoStyle(),
    sequenceNumStyle: ansi.NoStyle(),
    levelNameStyle: ansi.NoStyle(),
    timeStyle: ansi.NoStyle(),
    pathStyle: ansi.NoStyle(),
    messageStyles: {},
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
  );

  LogLevelTheme copyWith({
    int? maxLength,
    int? maxLines,
    ansi.Style? normalStyle,
    ansi.Style? boldStyle,
    ansi.Style? dimStyle,
    ansi.Style? superDimStyle,
    ansi.Style? sequenceNumStyle,
    ansi.Style? levelNameStyle,
    ansi.Style? timeStyle,
    ansi.Style? pathStyle,
    Map<String, ansi.Style>? messageStyles,
    LogPreFormatter? valueFormatter,
    LogPreFormatter? messageFormatter,
    ansi.Style? tagsStyle,
    ansi.Style? controlCodesStyle,
    ansi.Style? punctuationStyle,
    String? colon,
    ansi.Style? colonStyle,
    String? ellipsis,
    ansi.Style? ellipsisStyle,
    String? lineBreak,
    ansi.Style? lineBreakStyle,
    String? padding,
    ansi.Style? paddingStyle,
    ansi.Style? dataSectionStyle,
    ansi.Style? dataNameStyle,
    ansi.Style? dataKeyStyle,
    ansi.Style? dataValueStyle,
    ansi.Style? dataUnitsStyle,
    List<ansi.Style>? dataBracketsStyles,
    List<ansi.Style>? dataDescriptionStyles,
    List<ansi.Style>? dataPunctuationStyles,
    Set<String>? tags,
  }) {
    assert(padding == null || padding.length == 1);

    return LogLevelTheme._(
      normalStyle: normalStyle ?? this.normalStyle,
      boldStyle: boldStyle ?? this.boldStyle,
      dimStyle: dimStyle ?? this.dimStyle,
      superDimStyle: superDimStyle ?? this.superDimStyle,
      sequenceNumStyle: sequenceNumStyle ?? this.sequenceNumStyle,
      levelNameStyle: levelNameStyle ?? this.levelNameStyle,
      timeStyle: timeStyle ?? this.timeStyle,
      pathStyle: pathStyle ?? this.pathStyle,
      messageStyles: messageStyles ?? this.messageStyles,
      valueFormatter: valueFormatter ?? this.valueFormatter,
      messageFormatter: messageFormatter ?? this.messageFormatter,
      tagsStyle: tagsStyle ?? this.tagsStyle,
      controlCodesStyle: controlCodesStyle ?? this.controlCodesStyle,
      punctuationStyle: punctuationStyle ?? this.punctuationStyle,
      colonStyle: colonStyle ?? this.colonStyle,
      ellipsisStyle: ellipsisStyle ?? this.ellipsisStyle,
      lineBreakStyle: lineBreakStyle ?? this.lineBreakStyle,
      paddingStyle: paddingStyle ?? this.paddingStyle,
      dataSectionStyle: dataSectionStyle ?? this.dataSectionStyle,
      dataNameStyle: dataNameStyle ?? this.dataNameStyle,
      dataKeyStyle: dataKeyStyle ?? this.dataKeyStyle,
      dataValueStyle: dataValueStyle ?? this.dataValueStyle,
      dataUnitsStyle: dataUnitsStyle ?? this.dataUnitsStyle,
      dataBracketsStyles: dataBracketsStyles ?? this.dataBracketsStyles,
      dataDescriptionStyles:
          dataDescriptionStyles ?? this.dataDescriptionStyles,
      dataPunctuationStyles:
          dataPunctuationStyles ?? this.dataPunctuationStyles,
      tags: tags ?? this.tags,
    );
  }

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..style('normalStyle', normalStyle)
      ..style('boldStyle', boldStyle)
      ..style('dimStyle', dimStyle)
      ..style('superDimStyle', superDimStyle)
      ..style('sequenceNumStyle', sequenceNumStyle)
      ..style('levelNameStyle', levelNameStyle)
      ..style('timeStyle', timeStyle)
      ..style('pathStyle', pathStyle)
      ..mapStyles('messageStyles', messageStyles)
      ..prop('valueFormatter', valueFormatter)
      ..prop('messageFormatter', messageFormatter)
      ..style('tagsStyle', tagsStyle)
      ..style('controlCodesStyle', controlCodesStyle)
      ..style('punctuationStyle', punctuationStyle)
      ..style('colonStyle', colonStyle)
      ..style('ellipsisStyle', ellipsisStyle)
      ..style('lineBreakStyle', lineBreakStyle)
      ..style('paddingStyle', paddingStyle)
      ..style('dataSectionStyle', dataSectionStyle)
      ..style('dataNameStyle', dataNameStyle)
      ..style('dataKeyStyle', dataKeyStyle)
      ..style('dataValueStyle', dataValueStyle)
      ..style('dataUnitsStyle', dataUnitsStyle)
      ..styles('dataBracketsStyles', dataBracketsStyles, (_) => '[')
      ..styles('dataDescriptionStyles', dataDescriptionStyles, (i) => '$i')
      ..styles('dataPunctuationStyles', dataPunctuationStyles, (_) => ',')
      ..prop('tags', tags);
  }
}

extension on LoggableData {
  void style(String name, ansi.Style style, {bool showName = false}) {
    if (style is ansi.NoStyle) {
      prop(name, style, view: 'none');
      return;
    }

    prop(name, style, showName: showName, view: style(name));
  }

  void styles(
    String name,
    List<ansi.Style> styles,
    String Function(int i) getValue, {
    String separator = '',
  }) {
    final none =
        styles.fold(false, (none, style) => none || style is ansi.NoStyle);
    if (none) {
      prop(name, styles, view: 'none');
      return;
    }

    final values =
        styles.indexed.map((e) => e.$2(getValue(e.$1))).join(separator);
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
