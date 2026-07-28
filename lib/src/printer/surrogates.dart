/// Внутренние утилиты работы с суррогатными парами UTF-16 при обрезке
/// строк. Не экспортируется.
library;

final _trailingSgrRe = RegExp(r'(?:\x1B\[[0-9;]*m)*$');
final _leadingSgrRe = RegExp(r'^(?:\x1B\[[0-9;]*m)*');

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Обрезка по code units может разрезать суррогатную пару (эмодзи и т.п.),
/// оставив невалидную половину. Заменяет разрезанные половины на пробел,
/// сохраняя видимую ширину строки. Завершающие/ведущие SGR-коды ANSI
/// при проверке пропускаются.
String fixDanglingSurrogates(String s) {
  var result = s;

  final tailStart = _trailingSgrRe.firstMatch(result)!.start;
  if (tailStart > 0 && _isHighSurrogate(result.codeUnitAt(tailStart - 1))) {
    result =
        '${result.substring(0, tailStart - 1)} ${result.substring(tailStart)}';
  }

  final headEnd = _leadingSgrRe.firstMatch(result)!.end;
  if (headEnd < result.length && _isLowSurrogate(result.codeUnitAt(headEnd))) {
    result = '${result.substring(0, headEnd)} ${result.substring(headEnd + 1)}';
  }

  return result;
}
