import 'package:ansi_escape_codes/extensions.dart';
import 'package:meta/meta.dart';

import '../theme/log_theme.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';

/// Вспомогательный класс, помогающий получить описание класса для логирования
///
/// Позволяет:
/// - получить описание класса в виде строки, используя
///   [Loggable.objectToString] или [toString]
/// - получить с помощью [logClassInfo] описание класса в виде списка параметров,
///   которые можно потом наглядно показать в UI
mixin Loggable {
  /// Метод должен заполнить [data] описанием исследуемого класса.
  void collectLoggableData(LoggableData data);

  @nonVirtual
  LoggableData logClassInfo() {
    final data = LoggableData._(TypeProp(runtimeType));
    collectLoggableData(data);
    return data;
  }

  @override
  String toString() => logClassInfo().toLogString();

  static String objectToString(
    Object? obj, {
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int? collectionMaxCount,
    int? collectionMaxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) {
    showCount ??= theme.showCount;
    showIndexes ??= theme.showIndexes;

    final brackets = theme.bracketStyle(level);
    final content = theme.punctuationStyle(level);

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          preformat: preformat,
          theme: theme,
          collectionMaxCount: collectionMaxCount,
          collectionMaxLength: collectionMaxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        );

    String units2str() => Loggable.units2str(units, preformat, theme);

    String map2str(MapEntry<Object?, Object?> e) {
      final key = switch (e.key) {
        final String key => preformat?.call(key) ?? key,
        final key => obj2str(key),
      };

      return '${theme.key(key)}${content(':')}'
          ' ${theme.value(obj2str(e.value))}${units2str()}';
    }

    return switch (obj) {
      null => preformat?.call('null') ?? 'null',
      String() => '"${preformat?.call(obj) ?? obj}"${units2str()}',
      List<Object?>() => listToString(
          obj,
          level: level,
          preformat: preformat,
          theme: theme,
          maxCount: collectionMaxCount,
          maxLength: collectionMaxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        ),
      Set<Object?>() => setToString(
          obj,
          level: level,
          preformat: preformat,
          theme: theme,
          maxCount: collectionMaxCount,
          maxLength: collectionMaxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        ),
      Iterable<Object?>() => iterableToString(
          obj,
          level: level,
          preformat: preformat,
          theme: theme,
          maxCount: collectionMaxCount,
          maxLength: collectionMaxLength,
          showIndexes: showIndexes,
          units: units,
        ),
      Map<Object?, Object?>() => '${brackets('{')}'
          '${obj.entries.map(map2str).join(content(', '))}'
          '${brackets('}')}',
      Loggable() => obj.logClassInfo().toLogString(
            theme: theme,
            level: level,
            valueFormat: preformat,
            collectionMaxCount: collectionMaxCount,
            collectionMaxLength: collectionMaxLength,
            showCount: showCount,
            showIndexes: showIndexes,
            units: units,
          ),
      LoggableData() => obj.toLogString(
          theme: theme,
          level: level,
          valueFormat: preformat,
          collectionMaxCount: collectionMaxCount,
          collectionMaxLength: collectionMaxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        ),
      LoggableMultiData() => obj.data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: theme,
            preformat: preformat,
            collectionMaxCount: obj.collectionMaxCount ?? collectionMaxCount,
            collectionMaxLength: obj.collectionMaxLength ?? collectionMaxLength,
            showCount: obj.showCount ?? showCount,
            showIndexes: obj.showIndexes ?? showIndexes,
            units: obj.units ?? units,
          );
          return '${theme.title('[${e.key}]')} $value';
        }).join(content(', ')),
      _ => '${preformat?.call(obj.toString()) ?? obj}${units2str()}',
    };
  }

  /// Преобразует список в строку в виде `[first, …, last] (n=N)`.
  ///
  /// Если кол-во элементов в списке больше [maxCount] или длина строки больше
  /// [maxLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  static String listToString(
    List<Object?> list, {
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int? maxCount,
    int? maxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) =>
      efficientLengthIterableToString(
        list,
        level: level,
        preformat: preformat,
        theme: theme,
        start: '[',
        end: ']',
        maxCount: maxCount,
        maxLength: maxLength,
        showCount: showCount,
        showIndexes: showIndexes,
        units: units,
      );

  /// Преобразует набор в строку в виде `{first, …, last} (n=N)`.
  ///
  /// Если кол-во элементов в наборе больше [maxCount] или длина строки больше
  /// [maxLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  static String setToString(
    Set<Object?> set, {
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int? maxCount,
    int? maxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) =>
      efficientLengthIterableToString(
        set,
        level: level,
        preformat: preformat,
        theme: theme,
        start: '{',
        end: '}',
        maxCount: maxCount,
        maxLength: maxLength,
        showCount: showCount,
        showIndexes: showIndexes,
        units: units,
      );

  /// Преобразует коллекцию в строку в виде `(first, …, last) (n=N)`.
  ///
  /// Если кол-во элементов в коллекции больше [maxCount] или длина строки
  /// больше [maxLength], то результат будет урезан. Первый и последний
  /// элементы, если они есть, выводятся всегда.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    String start = '(',
    String end = ')',
    int? maxCount,
    int? maxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) {
    assert(maxCount == null || maxCount >= 2);
    assert(maxLength == null || maxLength > 0);
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    showIndexes ??= theme.showIndexes;
    showCount ??= theme.showCount;

    final brackets = theme.bracketStyle(level);
    final description = theme.descriptionStyle(level);
    final content = theme.punctuationStyle(level);
    final delimiter = content(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          preformat: preformat,
          theme: theme,
          collectionMaxCount: maxCount,
          collectionMaxLength: maxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        );

    String index2str(int index) => description(_index2str(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    final count = iterable.length;
    var buf = StringBuffer(brackets(start));
    var startLength = start.length;
    if (count > 1 && showCount) {
      final prefix = '(n=$count) ';
      startLength += prefix.length;
      buf.write(description(prefix));
    }

    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes && count > 1
            ? iterable.indexed
                .map((e) => indexedObj2str(e.$1, e.$2))
                .join(delimiter)
            : iterable.map(obj2str).join(delimiter),
      );
    } else {
      final iterator = iterable.iterator;

      if (iterator.moveNext()) {
        if (count == 1) {
          // Единственный выводим без индекса.
          buf.write(obj2str(iterator.current));
        } else if (count > 1) {
          // Первый выводим всегда.
          final first = showIndexes
              ? indexedObj2str(0, iterator.current)
              : obj2str(iterator.current);
          buf.write(first);

          // Последний, если есть, тоже выводим всегда.
          final last = showIndexes
              ? indexedObj2str(count - 1, iterable.last)
              : obj2str(iterable.last);
          var length = startLength +
              first.lengthWithoutEscapeCodes +
              2 +
              theme.ellipsis.length +
              2 +
              last.lengthWithoutEscapeCodes +
              end.length;
          var index = 1;
          maxCount ??= count;
          (StringBuffer, int)? copy;

          while (index < maxCount - 1 && index < count - 1) {
            iterator.moveNext();
            final item = showIndexes
                ? indexedObj2str(index, iterator.current)
                : obj2str(iterator.current);
            length += 2 + item.lengthWithoutEscapeCodes;
            if (maxLength != null && length > maxLength) {
              if (length - 2 - theme.ellipsis.length > maxLength) {
                break;
              } else {
                copy ??= (StringBuffer(buf.toString()), index);
              }
            }

            buf
              ..write(delimiter)
              ..write(item);
            index++;
          }

          if (index != count - 1) {
            if (copy != null) {
              (buf, index) = copy;
            }

            buf
              ..write(delimiter)
              ..write(content(theme.ellipsis));
          }

          buf
            ..write(delimiter)
            ..write(last);
        }
      }
    }

    buf.write(brackets(end));

    return buf.toString();
  }

  /// Преобразует коллекцию в строку в виде `(first, …) (n=N)`.
  ///
  /// Если кол-во элементов в коллекции больше [maxCount] или длина строки больше
  /// [maxLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String iterableToString(
    Iterable<Object?> iterable, {
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    String start = '(',
    String end = ')',
    int? maxCount,
    int? maxLength,
    bool? showIndexes,
    String? units,
  }) {
    assert(maxCount == null || maxCount >= 2);
    assert(maxLength == null || maxLength > 0);

    showIndexes ??= theme.showIndexes;

    final brackets = theme.bracketStyle(level);
    final description = theme.descriptionStyle(level);
    final content = theme.punctuationStyle(level);
    final delimiter = content(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          preformat: preformat,
          theme: theme,
          collectionMaxCount: maxCount,
          collectionMaxLength: maxLength,
          showIndexes: showIndexes,
          units: units,
        );

    String index2str(int index) => description(_index2str(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    var buf = StringBuffer(brackets(start));

    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes
            ? iterable.indexed
                .map((e) => indexedObj2str(e.$1, e.$2))
                .join(delimiter)
            : iterable.map(obj2str).join(delimiter),
      );
    } else {
      final iterator = iterable.iterator;

      if (iterator.moveNext()) {
        final firstItem = iterator.current;
        var hasNext = iterator.moveNext();

        if (!hasNext) {
          // Единственный выводим без индекса.
          buf.write(obj2str(firstItem));
        } else {
          // Первый выводим всегда.
          final first =
              showIndexes ? indexedObj2str(0, firstItem) : obj2str(firstItem);
          buf.write(first);

          var index = 1;
          var length = start.length +
              first.lengthWithoutEscapeCodes +
              2 +
              theme.ellipsis.length +
              end.length;
          var truncated = false;
          (StringBuffer, int)? copy;

          while ((maxCount == null || index < maxCount) && hasNext) {
            final item = showIndexes
                ? indexedObj2str(index, iterator.current)
                : obj2str(iterator.current);
            length += 2 + item.lengthWithoutEscapeCodes;
            if (maxLength != null && length > maxLength) {
              if (length - 2 - theme.ellipsis.length > maxLength) {
                truncated = true;
                break;
              } else {
                copy ??= (StringBuffer(buf.toString()), index);
              }
            }

            buf
              ..write(delimiter)
              ..write(item);
            index++;

            hasNext = iterator.moveNext();
          }

          if (truncated || iterator.moveNext()) {
            if (copy != null) {
              (buf, index) = copy;
            }

            buf
              ..write(delimiter)
              ..write(content(theme.ellipsis));
          }
        }
      }
    }

    buf.write(brackets(end));

    return buf.toString();
  }

  static String _index2str(int index) => '$index:';

  static String units2str(
    String? units,
    String Function(String value)? preformat,
    LogDataTheme theme,
  ) {
    final unitsStr = units ?? '';
    // final unitsStr = units == null ? '' : ' $units';

    return theme.units(preformat?.call(unitsStr) ?? unitsStr);
  }
}
