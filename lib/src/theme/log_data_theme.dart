part of 'log_theme.dart';

final class LogDataTheme with Loggable {
  final ansi.Style title;
  final ansi.Style name;
  final ansi.Style key;
  final ansi.Style value;
  final ansi.Style units;
  final List<ansi.Style> brackets;
  final List<ansi.Style> description;
  final List<ansi.Style> punctuation;
  final bool showCount;
  final bool showIndexes;
  final String ellipsis;

  const LogDataTheme._({
    required this.title,
    required this.name,
    required this.key,
    required this.value,
    required this.units,
    required this.brackets,
    required this.description,
    required this.punctuation,
    required this.showCount,
    required this.showIndexes,
    required this.ellipsis,
  });

  ansi.Style bracketStyle(int level) => brackets[level % brackets.length];

  ansi.Style descriptionStyle(int level) =>
      description[level % description.length];

  ansi.Style punctuationStyle(int level) =>
      punctuation[level % punctuation.length];

  static const LogDataTheme noColorsTheme = LogDataTheme._(
    title: ansi.NoStyle(),
    name: ansi.NoStyle(),
    key: ansi.NoStyle(),
    value: ansi.NoStyle(),
    units: ansi.NoStyle(),
    brackets: [ansi.NoStyle()],
    description: [ansi.NoStyle()],
    punctuation: [ansi.NoStyle()],
    showCount: true,
    showIndexes: true,
    ellipsis: '…',
  );

  @override
  void collectLoggableData(LoggableData data) {
    // Brackets
    final bracketsBuf = StringBuffer('"');
    for (final style in brackets) {
      bracketsBuf.write(style('['));
    }
    bracketsBuf.write('"');

    // Description
    final descriptionBuf = StringBuffer('"');
    for (final (index, style) in description.indexed) {
      descriptionBuf.write(style('$index'));
    }
    descriptionBuf.write('"');

    // Punctuation
    final punctuationBuf = StringBuffer('"');
    for (final style in punctuation) {
      punctuationBuf.write(style(','));
    }
    punctuationBuf.write('"');

    data
      ..prop('title', title, showName: false, view: title('title'))
      ..prop('name', name, showName: false, view: name('name'))
      ..prop('key', key, showName: false, view: key('key'))
      ..prop('value', value, showName: false, view: value('value'))
      ..prop('units', units, showName: false, view: units('units'))
      ..prop('brackets', brackets, view: '$bracketsBuf')
      ..prop('description', description, view: '$descriptionBuf')
      ..prop('punctuation', punctuation, view: '$punctuationBuf')
      ..prop('showCount', showCount)
      ..prop('showIndexes', showIndexes)
      ..prop('ellipsis', ellipsis);
  }
}
