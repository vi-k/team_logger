import 'package:ansi_escape_codes/extensions.dart';
import 'package:meta/meta.dart';

import '../theme/log_theme.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';

/// Вспомогательный класс, помогающий получить описание класса для логирования.
///
/// Позволяет:
///
/// - получить описание класса в виде строки, используя
///   [Loggable.objectToString] или [toString].
/// - получить с помощью [logClassInfo] описание класса в виде списка
///   параметров, которые можно потом наглядно показать в UI.
abstract mixin class Loggable {
  static final Map<Type, LoggableTypeConverter<Object?>> _converters = {};

  /// Метод должен заполнить [data] описанием исследуемого класса.
  void collectLoggableData(LoggableData data);

  /// Создает [Loggable] из любого объекта.
  ///
  /// Имеет смысл использовать только для примитивных типов, enums, коллекций
  /// и [Loggable] с целью передачи параметров логирования. Для других
  /// объектов, не поддерживающих [Loggable] напрямую, используйте
  /// [Loggable.builder].
  ///
  /// В случае [Loggable] выполняет роль обёртки, чтобы передать параметры,
  /// не установленные самим объектом.
  ///
  /// Параметры будут переданы в [Loggable.objectToString].
  factory Loggable.from(
    Object? obj, {
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) =>
      _LoggableWrapper(
        obj,
        enumDotShorthand: enumDotShorthand,
        collectionMaxLength: collectionMaxLength,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowLength: collectionShowLength,
        collectionShowIndexes: collectionShowIndexes,
        units: units,
      );

  /// Позволяет создать [LoggableData] для любого объекта, изначально
  /// не поддерживающего [Loggable].
  ///
  /// ```dart
  /// const obj = NotLoggableData(a: 'abc', b: [1, 2, 3]);
  /// log.d(
  ///   'object',
  ///   data: Loggable.builder(obj)
  ///     ..prop('a', obj.a)
  ///     ..prop('b', obj.b, collectionMaxLength: 2),
  /// );
  /// // object: NotLoggableData(a: "abc", b: [₌₃ ₀:1, …, ₂:3])
  /// ```
  ///
  /// В определённых случаях, возможно, вы захотите не показывать имя класса
  /// или скобки. Для этого используйте параметры [showName] и [showBrackets]:
  ///
  /// ```dart
  /// final point = Point(lat: 27.988056, lon: 86.925278);
  /// log.d(
  ///   'Mount Everest',
  ///   data: Loggable.builder(point, showName: false, showBrackets: false)
  ///     ..prop('lat', point.lat, showName: false)
  ///     ..prop('lon', point.lon, showName: false),
  /// );
  /// // Mount Everest: 27.988056, 86.925278
  /// ```
  ///
  /// Если вам нужны свои скобки, отличные от стандартных `()`, используйте
  /// [openingBracket] и [closingBracket]:
  static LoggableData builder(
    Object? value, {
    String? name,
    bool showName = true,
    bool showBrackets = true,
    String? openingBracket,
    String? closingBracket,
  }) =>
      _LoggableBuilder(
        value,
        name: name,
        showName: showName,
        showBrackets: showBrackets,
        openingBracket: openingBracket,
        closingBracket: closingBracket,
      );

  /// Позволяет создать из [LoggableData] структуру, схожую с [Map].
  ///
  /// ```dart
  /// log.d('map', data: {'a': 1, 'b': 2, 'c': 3});
  /// // map: {a: 1, b: 2, c: 3}
  ///
  /// log.d('map', data: Loggable.mapBuilder()
  ///     ..prop('a', 1, units: 'kg')
  ///     ..prop('b', 2, units: 'm')
  ///     ..prop('c', 3, units: 'sec'),
  /// );
  /// // map: {a: 1kg, b: 2m, c: 3sec}
  /// ```
  static LoggableData mapBuilder() => _LoggableMapBuilder();

  static void registerTypeConverter<T extends Object?>(
    LoggableTypeConverter<T> converter,
  ) {
    _converters[T] = converter as LoggableTypeConverter<Object?>;
  }

  static void unregisterTypeConverter<T>() {
    _converters.remove(T);
  }

  @nonVirtual
  LoggableData logClassInfo() {
    final data = LoggableData._(TypeProp(runtimeType));
    collectLoggableData(data);
    return data;
  }

  @override
  String toString() => logClassInfo().toLogString();

  /// Преобразует объект в строку, используя тему [theme].
  ///
  /// Параметры:
  ///
  /// [enumDotShorthand] - сокращенное представление enums в виде `.value`.
  /// Значение по умолчанию берётся из [LogTheme.enumDotShorthand].
  ///
  /// [collectionMaxLength] - максимальное количество элементов в коллекции
  /// (для List, Set и Iterable). По умолчанию без ограничений.
  ///
  /// [collectionMaxStringLength] - максимальная длина результирующей строки
  /// после преобразования коллекции. В реальности строка может быть больше,
  /// т.к. итерируемые объекты обязательно должны содержать первый элемент,
  /// а списки первый и последний элемент без сокращений. По умолчанию без
  /// ограничений.
  ///
  /// [collectionShowLength] - показывать ли длину коллекции в виде `₌₄`
  /// (только для List и Set). Значение по умолчанию берётся из
  /// [LogTheme.collectionShowLength].
  ///
  /// [collectionShowIndexes] - показывать ли индексы элементов в виде `₀:`,
  /// `₁:` и т.д. Значение по умолчанию берётся из
  /// [LogTheme.collectionShowIndexes].
  ///
  /// [units] - единицы измерения, будут добавлены к представлению объекта
  /// в виде суффикса. По умолчанию без единиц.
  ///
  /// Все параметры действуют рекурсивно не только на сам объект,
  /// но и на все вложенные в него объекты:
  ///
  /// ```dart
  /// log.d(
  ///   'data',
  ///   data: Loggable.from(
  ///     [1, 2, [3, 4, 5]],
  ///     units: 'kg',
  ///     collectionMaxLength: 2,
  ///   ),
  /// );
  /// // data: [₌₃ ₀:1kg, …, ₂:[₌₃ ₀:3kg, …, ₂:5kg]]
  /// ```
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
    final levelTheme = theme.dataLevelTheme(level);

    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter(
        obj,
        level,
        theme,
        enumDotShorthand ?? theme.common.enumDotShorthand,
        collectionMaxLength,
        collectionMaxStringLength,
        collectionShowLength ?? theme.common.collectionShowLength,
        collectionShowIndexes ?? theme.common.collectionShowIndexes,
        units,
      );
    }

    switch (obj) {
      case null:
        return theme.formatValue('null');

      case Enum():
        return enumToString(
          obj,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
        );

      case String():
        return stringToString(obj, theme: theme, units: units);

      case List<Object?>():
        return listToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

      case Set<Object?>():
        return setToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

      case Iterable<Object?>():
        return iterableToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

      case Map<Object?, Object?>():
        return mapToString(
          obj,
          level: level,
          theme: theme,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

      case Loggable():
        return obj.logClassInfo().toLogString(
              theme: theme,
              level: level,
              enumDotShorthand: enumDotShorthand,
              collectionMaxLength: collectionMaxLength,
              collectionMaxStringLength: collectionMaxStringLength,
              collectionShowLength: collectionShowLength,
              collectionShowIndexes: collectionShowIndexes,
              units: units,
            );

      case LoggableData():
        return obj.toLogString(
          theme: theme,
          level: level,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

      case LoggableMultiData():
        return obj.data.entries.map((e) {
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
        }).join(levelTheme.punctuation(', '));

      default:
        return '${theme.formatValue(obj.toString())}'
            '${unitsToString(units, theme)}';
    }
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

    final fixedCollectionShowLength =
        collectionShowLength ?? theme.common.collectionShowLength;
    final fixedCollectionShowIndexes =
        collectionShowIndexes ?? theme.common.collectionShowIndexes;

    final levelTheme = theme.dataLevelTheme(level);
    final delimiter = levelTheme.punctuation(', ');

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
        levelTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    final count = iterable.length;
    var buf = StringBuffer(levelTheme.brackets(start));
    var startLength = start.length;
    if (count > 1 && fixedCollectionShowLength) {
      final prefix = theme.formatCount(count);
      startLength += prefix.length;
      buf.write(levelTheme.description(prefix));
    }

    if (collectionMaxStringLength == null && collectionMaxLength == null) {
      buf.write(
        fixedCollectionShowIndexes && count > 1
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
          final first = fixedCollectionShowIndexes
              ? indexedObj2str(0, iterator.current)
              : obj2str(iterator.current);
          buf.write(first);

          // Последний, если есть, тоже выводим всегда.
          final last = fixedCollectionShowIndexes
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
          final fixedCollectionMaxLength = collectionMaxLength ?? count;
          (StringBuffer, int)? copy;

          while (index < fixedCollectionMaxLength - 1 && index < count - 1) {
            iterator.moveNext();
            final item = fixedCollectionShowIndexes
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
              ..write(levelTheme.punctuation(theme.common.ellipsis));
          }

          buf
            ..write(delimiter)
            ..write(last);
        }
      }
    }

    buf.write(levelTheme.brackets(end));

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

    final fixedCollectionShowIndexes =
        collectionShowIndexes ?? theme.common.collectionShowIndexes;

    final levelTheme = theme.dataLevelTheme(level);
    final delimiter = levelTheme.punctuation(', ');

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
        levelTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    var buf = StringBuffer(levelTheme.brackets(start));

    if (collectionMaxStringLength == null && collectionMaxLength == null) {
      buf.write(
        fixedCollectionShowIndexes
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
          final first = fixedCollectionShowIndexes
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
            final item = fixedCollectionShowIndexes
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
              ..write(levelTheme.punctuation(theme.common.ellipsis));
          }
        }
      }
    }

    buf.write(levelTheme.brackets(end));

    return buf.toString();
  }

  static String mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowIndexes,
    bool? collectionShowLength,
    String? units,
  }) {
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

    final levelTheme = theme.dataLevelTheme(level);

    final key = switch (entry.key) {
      final String key => theme.formatValue(key),
      final key => obj2str(key),
    };

    return '${theme.dataKeyStyle(key)}${levelTheme.punctuation(':')}'
        ' ${theme.dataValueStyle(obj2str(entry.value))}'
        '${unitsToString(units, theme)}';
  }

  static String mapToString(
    Map<Object?, Object?> map, {
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '{',
    String end = '}',
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowIndexes,
    bool? collectionShowLength,
    String? units,
  }) {
    final levelTheme = theme.dataLevelTheme(level);
    final body = map.entries
        .map(
          (e) => mapEntryToString(
            e,
            level: level,
            theme: theme,
            enumDotShorthand: enumDotShorthand,
            collectionMaxLength: collectionMaxLength,
            collectionMaxStringLength: collectionMaxStringLength,
            collectionShowLength: collectionShowLength,
            collectionShowIndexes: collectionShowIndexes,
            units: units,
          ),
        )
        .join(levelTheme.punctuation(', '));

    return '${levelTheme.brackets(start)}$body${levelTheme.brackets(end)}';
  }

  static String enumToString(
    Enum obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
  }) {
    final dotShorthand = '.${theme.formatValue(obj.name)}';

    return (enumDotShorthand ?? theme.common.enumDotShorthand)
        ? dotShorthand
        : '${obj.runtimeType}${theme.emphasis(dotShorthand)}';
  }

  static String stringToString(
    String obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    String? units,
  }) =>
      '${theme.styledOpeningQuote}'
      '${theme.formatValue(obj)}'
      '${theme.styledClosingQuote}'
      '${unitsToString(units, theme)}';

  static String unitsToString(
    String? units,
    LogLevelTheme theme,
  ) =>
      units == null ? '' : theme.dataUnitsStyle(theme.formatValue(units));
}

final class _LoggableWrapper with Loggable {
  final LoggableData _data;

  _LoggableWrapper(
    Object? obj, {
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) : _data = LoggableData._(
          const TypeProp(
            Object,
            showName: false,
            showBrackets: false,
          ),
        ) {
    _data.prop(
      'obj',
      obj,
      showName: false,
      enumDotShorthand: enumDotShorthand,
      collectionMaxLength: collectionMaxLength,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowLength: collectionShowLength,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      levelCorrection: -1,
    );
  }

  @override
  // ignore: invalid_override_of_non_virtual_member
  LoggableData logClassInfo() => _data;

  @override
  void collectLoggableData(LoggableData data) {}
}

abstract interface class LoggableTypeConverter<T extends Object?> {
  String call(
    T obj,
    int level,
    LogLevelTheme theme,
    bool enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool collectionShowLength,
    bool collectionShowIndexes,
    String? units,
  );
}
