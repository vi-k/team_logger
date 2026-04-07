import 'package:ansi_escape_codes/extensions.dart';
import 'package:meta/meta.dart';

import 'log_data_theme.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';

const defaultShowIndexes = true;

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
    final data = LoggableData._(ClassProp(runtimeType));
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
    bool? showIndexes,
    String? units,
  }) {
    showIndexes ??= defaultShowIndexes;

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          preformat: preformat,
          theme: theme,
          collectionMaxCount: collectionMaxCount,
          collectionMaxLength: collectionMaxLength,
          showIndexes: showIndexes,
          units: units,
        );

    String units2str() => Loggable.units2str(units, preformat, theme);

    String map2str(MapEntry<Object?, Object?> e) {
      final key = switch (e.key) {
        final String key => preformat?.call(key) ?? key,
        final key => obj2str(key),
      };

      return '${theme.key(key)}: ${theme.value(obj2str(e.value))}${units2str()}';
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
      Map<Object?, Object?>() => '${theme.level(level)('{')}'
          '${obj.entries.map(map2str).join(', ')}'
          '${theme.level(level)('}')}',
      Loggable() => obj.logClassInfo().toLogString(
            theme: theme,
            level: level,
            valueFormat: preformat,
            collectionMaxCount: collectionMaxCount,
            collectionMaxLength: collectionMaxLength,
            showIndexes: showIndexes,
            units: units,
          ),
      LoggableData() => obj.toLogString(
          theme: theme,
          level: level,
          valueFormat: preformat,
          collectionMaxCount: collectionMaxCount,
          collectionMaxLength: collectionMaxLength,
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
            showIndexes: obj.showIndexes ?? showIndexes,
            units: obj.units ?? units,
          );
          return '${theme.title('[${e.key}]')} $value';
        }).join(', '),
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
    bool? showIndexes,
    String? units,
  }) {
    assert(maxCount == null || maxCount >= 2);
    assert(maxLength == null || maxLength > 0);
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    showIndexes ??= defaultShowIndexes;

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

    String index2str(int index) => theme.index(_index2str(index));

    var buf = StringBuffer(theme.level(level)(start));

    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes
            ? iterable.indexed
                .map((e) => '${index2str(e.$1)}${obj2str(e.$2)}')
                .join(', ')
            : iterable.map(obj2str).join(', '),
      );
    } else {
      final count = iterable.length;
      final iterator = iterable.iterator;

      if (iterator.moveNext()) {
        // Первый выводим всегда.
        final first = showIndexes
            ? '${index2str(0)}${obj2str(iterator.current)}'
            : obj2str(iterator.current);
        buf.write(first);

        if (count > 1) {
          // Последний, если есть, тоже выводим всегда.
          final last = showIndexes
              ? '${index2str(count - 1)}${obj2str(iterator.current)}'
              : obj2str(iterator.current);
          var length = start.length +
              first.lengthWithoutEscapeCodes +
              2 +
              theme.ellipsis.length +
              2 +
              last.lengthWithoutEscapeCodes +
              end.length;
          var index = 1;
          maxCount ??= count;
          (StringBuffer, int)? copy;

          while (index < maxCount - 1 && iterator.moveNext()) {
            final item = showIndexes
                ? '${index2str(index)}${obj2str(iterator.current)}'
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
              ..write(', ')
              ..write(item);
            index++;
          }

          if (index != count - 1) {
            if (copy != null) {
              (buf, index) = copy;
            }

            buf
              ..write(', ')
              ..write(theme.ellipsis);
          }

          buf
            ..write(', ')
            ..write(last);
        }
      }
    }

    buf.write(theme.level(level)(end));

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

    showIndexes ??= defaultShowIndexes;

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

    String index2str(int index) => theme.index(_index2str(index));

    var buf = StringBuffer(theme.level(level)(start));

    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes
            ? iterable.indexed
                .map((e) => '${index2str(e.$1)}${obj2str(e.$2)}')
                .join(', ')
            : iterable.map(obj2str).join(', '),
      );
    } else {
      final iterator = iterable.iterator;

      if (iterator.moveNext()) {
        // Первый выводим всегда.
        final first = showIndexes
            ? '${index2str(0)}${obj2str(iterator.current)}'
            : obj2str(iterator.current);
        buf.write(first);

        var index = 1;
        var length = start.length +
            first.lengthWithoutEscapeCodes +
            2 +
            theme.ellipsis.length +
            end.length;
        var truncated = false;
        (StringBuffer, int)? copy;

        while ((maxCount == null || index < maxCount) && iterator.moveNext()) {
          final item = showIndexes
              ? '${index2str(index)}${obj2str(iterator.current)}'
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
            ..write(', ')
            ..write(item);
          index++;
        }

        if (truncated || iterator.moveNext()) {
          if (copy != null) {
            (buf, index) = copy;
          }

          buf
            ..write(', ')
            ..write(theme.ellipsis);
        }
      }
    }

    buf.write(theme.level(level)(end));

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
