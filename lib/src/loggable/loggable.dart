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
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) {
    enumDotShorthand ??= theme.common.enumDotShorthand;
    collectionShowLength ??= theme.common.collectionShowLength;
    collectionShowIndexes ??= theme.common.collectionShowIndexes;

    final blockStyle = theme.dataBlockStyle(level);

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

    String units2str() => Loggable.units2str(units, theme);

    String map2str(MapEntry<Object?, Object?> e) {
      final key = switch (e.key) {
        final String key => theme.formatValue(key),
        final key => obj2str(key),
      };

      return '${theme.dataKeyStyle(key)}${blockStyle.punctuation(':')}'
          ' ${theme.dataValueStyle(obj2str(e.value))}${units2str()}';
    }

    return switch (obj) {
      null => theme.formatValue('null'),
      Enum() => enumDotShorthand
          ? '.${theme.formatValue(obj.name)}'
          : '${theme.formatValue(obj.runtimeType.toString())}'
              '${theme.emphasis('.${theme.formatValue(obj.name)}')}',
      String() => '${theme.styledOpeningQuote}'
          '${theme.formatValue(obj)}'
          '${theme.styledClosingQuote}'
          '${units2str()}',
      List<Object?>() => listToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        ),
      Set<Object?>() => setToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        ),
      Iterable<Object?>() => iterableToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        ),
      Map<Object?, Object?>() => '${blockStyle.brackets('{')}'
          '${obj.entries.map(map2str).join(blockStyle.punctuation(', '))}'
          '${blockStyle.brackets('}')}',
      Loggable() => obj.logClassInfo().toLogString(
            theme: theme,
            level: level,
            enumDotShorthand: enumDotShorthand,
            collectionMaxLength: collectionMaxLength,
            collectionMaxStringLength: collectionMaxStringLength,
            collectionShowLength: collectionShowLength,
            collectionShowIndexes: collectionShowIndexes,
            units: units,
          ),
      LoggableData() => obj.toLogString(
          theme: theme,
          level: level,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        ),
      LoggableMultiData() => obj.data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: theme,
            enumDotShorthand: obj.enumDotShorthand ?? enumDotShorthand,
            collectionMaxLength: obj.collectionMaxLength ?? collectionMaxLength,
            collectionMaxStringLength:
                obj.collectionMaxStringLength ?? collectionMaxStringLength,
            collectionShowLength:
                obj.collectionShowLength ?? collectionShowLength,
            collectionShowIndexes:
                obj.collectionShowIndexes ?? collectionShowIndexes,
            units: obj.units ?? units,
          );

          return switch (e.key) {
            '' => value,
            final key =>
              '${theme.sectionStyle(key)}${theme.styledColon} $value',
          };
        }).join(blockStyle.punctuation(', ')),
      _ => '${theme.formatValue(obj.toString())}${units2str()}',
    };
  }

  /// Преобразует список в строку в виде `[first, …, last] (n=N)`.
  ///
  /// Если кол-во элементов в списке больше [collectionMaxLength] или длина строки больше
  /// [collectionMaxStringLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  static String listToString(
    List<Object?> list, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) =>
      efficientLengthIterableToString(
        list,
        level: level,
        theme: theme,
        start: '[',
        end: ']',
        enumDotShorthand: enumDotShorthand,
        collectionMaxLength: collectionMaxLength,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowLength: collectionShowLength,
        collectionShowIndexes: collectionShowIndexes,
        units: units,
      );

  /// Преобразует набор в строку в виде `{first, …, last} (n=N)`.
  ///
  /// Если кол-во элементов в наборе больше [collectionMaxLength] или длина строки больше
  /// [collectionMaxStringLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  static String setToString(
    Set<Object?> set, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) =>
      efficientLengthIterableToString(
        set,
        level: level,
        theme: theme,
        start: '{',
        end: '}',
        enumDotShorthand: enumDotShorthand,
        collectionMaxLength: collectionMaxLength,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowLength: collectionShowLength,
        collectionShowIndexes: collectionShowIndexes,
        units: units,
      );

  /// Преобразует коллекцию в строку в виде `(first, …, last) (n=N)`.
  ///
  /// Если кол-во элементов в коллекции больше [collectionMaxLength] или длина строки
  /// больше [collectionMaxStringLength], то результат будет урезан. Первый и последний
  /// элементы, если они есть, выводятся всегда.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '(',
    String end = ')',
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) {
    assert(collectionMaxLength == null || collectionMaxLength >= 2);
    assert(collectionMaxStringLength == null || collectionMaxStringLength > 0);
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    enumDotShorthand ??= theme.common.enumDotShorthand;
    collectionShowIndexes ??= theme.common.collectionShowIndexes;
    collectionShowLength ??= theme.common.collectionShowLength;

    final blockStyle = theme.dataBlockStyle(level);
    final delimiter = blockStyle.punctuation(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

    String index2str(int index) =>
        blockStyle.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    final count = iterable.length;
    var buf = StringBuffer(blockStyle.brackets(start));
    var startLength = start.length;
    if (count > 1 && collectionShowLength) {
      final prefix = theme.formatCount(count);
      startLength += prefix.length;
      buf.write(blockStyle.description(prefix));
    }

    if (collectionMaxStringLength == null && collectionMaxLength == null) {
      buf.write(
        collectionShowIndexes && count > 1
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
          final first = collectionShowIndexes
              ? indexedObj2str(0, iterator.current)
              : obj2str(iterator.current);
          buf.write(first);

          // Последний, если есть, тоже выводим всегда.
          final last = collectionShowIndexes
              ? indexedObj2str(count - 1, iterable.last)
              : obj2str(iterable.last);
          var length = startLength +
              first.lengthWithoutEscapeCodes +
              2 +
              theme.common.ellipsis.length +
              2 +
              last.lengthWithoutEscapeCodes +
              end.length;
          var index = 1;
          collectionMaxLength ??= count;
          (StringBuffer, int)? copy;

          while (index < collectionMaxLength - 1 && index < count - 1) {
            iterator.moveNext();
            final item = collectionShowIndexes
                ? indexedObj2str(index, iterator.current)
                : obj2str(iterator.current);
            length += 2 + item.lengthWithoutEscapeCodes;
            if (collectionMaxStringLength != null &&
                length > collectionMaxStringLength) {
              if (length - 2 - theme.common.ellipsis.length >
                  collectionMaxStringLength) {
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
              ..write(blockStyle.punctuation(theme.common.ellipsis));
          }

          buf
            ..write(delimiter)
            ..write(last);
        }
      }
    }

    buf.write(blockStyle.brackets(end));

    return buf.toString();
  }

  /// Преобразует коллекцию в строку в виде `(first, …) (n=N)`.
  ///
  /// Если кол-во элементов в коллекции больше [collectionMaxLength] или длина строки больше
  /// [collectionMaxStringLength], то результат будет урезан. Первый и последний элементы, если
  /// они есть, выводятся всегда.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String iterableToString(
    Iterable<Object?> iterable, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '(',
    String end = ')',
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowIndexes,
    bool? collectionShowLength,
    String? units,
  }) {
    assert(collectionMaxLength == null || collectionMaxLength >= 2);
    assert(collectionMaxStringLength == null || collectionMaxStringLength > 0);

    enumDotShorthand ??= theme.common.enumDotShorthand;
    collectionShowIndexes ??= theme.common.collectionShowIndexes;
    collectionShowLength ??= theme.common.collectionShowLength;

    final blockStyle = theme.dataBlockStyle(level);
    final delimiter = blockStyle.punctuation(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          level: level + 1,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowIndexes: collectionShowIndexes,
          collectionShowLength: collectionShowLength,
          units: units,
        );

    String index2str(int index) =>
        blockStyle.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    var buf = StringBuffer(blockStyle.brackets(start));

    if (collectionMaxStringLength == null && collectionMaxLength == null) {
      buf.write(
        collectionShowIndexes
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
          final first = collectionShowIndexes
              ? indexedObj2str(0, firstItem)
              : obj2str(firstItem);
          buf.write(first);

          var index = 1;
          var length = start.length +
              first.lengthWithoutEscapeCodes +
              2 +
              theme.common.ellipsis.length +
              end.length;
          var truncated = false;
          (StringBuffer, int)? copy;

          while ((collectionMaxLength == null || index < collectionMaxLength) &&
              hasNext) {
            final item = collectionShowIndexes
                ? indexedObj2str(index, iterator.current)
                : obj2str(iterator.current);
            length += 2 + item.lengthWithoutEscapeCodes;
            if (collectionMaxStringLength != null &&
                length > collectionMaxStringLength) {
              if (length - 2 - theme.common.ellipsis.length >
                  collectionMaxStringLength) {
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
              ..write(blockStyle.punctuation(theme.common.ellipsis));
          }
        }
      }
    }

    buf.write(blockStyle.brackets(end));

    return buf.toString();
  }

  static String units2str(
    String? units,
    LogLevelTheme theme,
  ) {
    final unitsStr = units ?? '';

    return theme.dataUnitsStyle(theme.formatValue(unitsStr));
  }

  // static final _reDigits = RegExp('[0-9]');
  // static final _normal0Code = '0'.codeUnitAt(0);
  // static final _small0Code = '₀'.codeUnitAt(0);
  // static String subscript(int n) => n.toString().replaceAllMapped(
  //       _reDigits,
  //       (m) => String.fromCharCode(
  //         m[0]!.codeUnitAt(0) - _normal0Code + _small0Code,
  //       ),
  //     );
}
