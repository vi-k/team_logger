import 'package:ansi_escape_codes/extensions.dart';
import 'package:format/format.dart';
import 'package:meta/meta.dart';

import '../theme/log_theme.dart';
import 'loggable_config.dart';
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
    LoggableConfig config = const LoggableConfig(),
  }) =>
      _LoggableWrapper(obj, config: config);

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

  /// Преобразует объект в строку, используя тему [theme] и конфигурацию
  /// [config].
  static String objectToString(
    Object? obj, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dataTheme = theme.dataLevelTheme(dataLevel);

    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter(
        obj,
        dataLevel,
        theme,
        config.resolved(theme.common),
      );
    }

    switch (obj) {
      case null:
        return theme.formatValue('null');

      case Enum():
        return enumToString(obj, theme: theme, config: config);

      case double():
        return doubleToString(obj, theme: theme, config: config);

      case int():
        return intToString(obj, theme: theme, config: config);

      case String():
        return stringToString(obj, theme: theme, config: config);

      case List<Object?>():
        return listToString(
          obj,
          dataLevel: dataLevel,
          theme: theme,
          config: config,
        );

      case Set<Object?>():
        return setToString(
          obj,
          dataLevel: dataLevel,
          theme: theme,
          config: config,
        );

      case Iterable<Object?>():
        return iterableToString(
          obj,
          dataLevel: dataLevel,
          theme: theme,
          config: config,
        );

      case Map<Object?, Object?>():
        return mapToString(
          obj,
          dataLevel: dataLevel,
          theme: theme,
          config: config,
        );

      case Loggable():
        return obj
            .logClassInfo()
            .toLogString(theme: theme, dataLevel: dataLevel, config: config);

      case LoggableData():
        return obj.toLogString(
          theme: theme,
          dataLevel: dataLevel,
          config: config,
        );

      case LoggableMultiData():
        return obj.data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: theme,
            config: obj.config.merge(config),
          );

          return switch (e.key) {
            '' => value,
            final key =>
              '${theme.sectionStyle(key)}${theme.styledColon} $value',
          };
        }).join(dataTheme.punctuation(', '));

      default:
        return '${theme.formatValue(obj.toString())}'
            '${unitsToString(config.units, theme)}';
    }
  }

  /// Преобразует список в строку в виде `[first, …, last] (n=N)`.
  ///
  /// See [efficientLengthIterableToString].
  static String listToString(
    List<Object?> list, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        list,
        dataLevel: dataLevel,
        theme: theme,
        start: '[',
        end: ']',
        config: config,
      );

  /// Преобразует набор в строку в виде `{first, …, last} (n=N)`.
  ///
  /// See [efficientLengthIterableToString].
  static String setToString(
    Set<Object?> set, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        set,
        dataLevel: dataLevel,
        theme: theme,
        start: '{',
        end: '}',
        config: config,
      );

  /// Преобразует коллекцию в строку в виде `(first, …, last) (n=N)`.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  ///
  /// Если кол-во элементов в коллекции больше
  /// [LoggableConfig.collectionMaxLength] или длина строки больше
  /// [LoggableConfig.collectionMaxStringLength], то результат будет урезан.
  /// Первый и последний элементы, если они есть, выводятся всегда.
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    assert(
      config.collectionMaxLength == null || config.collectionMaxLength! >= 2,
    );
    assert(
      config.collectionMaxStringLength == null ||
          config.collectionMaxStringLength! > 0,
    );
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    final resolvedCollectionShowLength =
        config.collectionShowLength ?? theme.common.collectionShowLength;
    final resolvedCollectionShowIndexes =
        config.collectionShowIndexes ?? theme.common.collectionShowIndexes;

    final dataTheme = theme.dataLevelTheme(dataLevel);
    final delimiter = dataTheme.punctuation(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          dataLevel: dataLevel + 1,
          theme: theme,
          config: config,
        );

    String index2str(int index) =>
        dataTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    final count = iterable.length;
    var buf = StringBuffer(dataTheme.brackets(start));
    var startLength = start.length;
    if (count > 1 && resolvedCollectionShowLength) {
      final prefix = '${theme.formatCount(count)} ';
      startLength += prefix.length;
      buf.write(dataTheme.description(prefix));
    }

    final collectionMaxLength = config.collectionMaxLength;
    final collectionMaxStringLength = config.collectionMaxStringLength;
    if (collectionMaxStringLength == null && collectionMaxLength == null) {
      buf.write(
        resolvedCollectionShowIndexes && count > 1
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
          final first = resolvedCollectionShowIndexes
              ? indexedObj2str(0, iterator.current)
              : obj2str(iterator.current);
          buf.write(first);

          // Последний, если есть, тоже выводим всегда.
          final last = resolvedCollectionShowIndexes
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
            final item = resolvedCollectionShowIndexes
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
              ..write(dataTheme.punctuation(theme.common.ellipsis));
          }

          buf
            ..write(delimiter)
            ..write(last);
        }
      }
    }

    buf.write(dataTheme.brackets(end));

    return buf.toString();
  }

  /// Преобразует коллекцию в строку в виде `(first, …) (n=N)`.
  ///
  /// Если кол-во элементов в коллекции больше
  /// [LoggableConfig.collectionMaxLength] или длина строки больше
  /// [LoggableConfig.collectionMaxStringLength], то результат будет урезан.
  /// Первый и последний элементы, если они есть, выводятся всегда.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String iterableToString(
    Iterable<Object?> iterable, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    assert(
      config.collectionMaxLength == null || config.collectionMaxLength! >= 2,
    );
    assert(
      config.collectionMaxStringLength == null ||
          config.collectionMaxStringLength! > 0,
    );

    final fixedCollectionShowIndexes =
        config.collectionShowIndexes ?? theme.common.collectionShowIndexes;

    final dataTheme = theme.dataLevelTheme(dataLevel);
    final delimiter = dataTheme.punctuation(', ');

    String obj2str(Object? obj) => objectToString(
          obj,
          dataLevel: dataLevel + 1,
          theme: theme,
          config: config,
        );

    String index2str(int index) =>
        dataTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    var buf = StringBuffer(dataTheme.brackets(start));

    final collectionMaxLength = config.collectionMaxLength;
    final collectionMaxStringLength = config.collectionMaxStringLength;
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
              ..write(dataTheme.punctuation(theme.common.ellipsis));
          }
        }
      }
    }

    buf.write(dataTheme.brackets(end));

    return buf.toString();
  }

  static String mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    String obj2str(Object? obj) => objectToString(
          obj,
          dataLevel: dataLevel + 1,
          theme: theme,
          config: config,
        );

    final dataTheme = theme.dataLevelTheme(dataLevel);

    final key = switch (entry.key) {
      final String key => theme.formatValue(key),
      final key => obj2str(key),
    };

    return '${theme.dataKeyStyle(key)}${dataTheme.punctuation(':')}'
        ' ${theme.dataValueStyle(obj2str(entry.value))}'
        '${unitsToString(config.units, theme)}';
  }

  static String mapToString(
    Map<Object?, Object?> map, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    String start = '{',
    String end = '}',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dataTheme = theme.dataLevelTheme(dataLevel);
    final body = map.entries
        .map(
          (e) => mapEntryToString(
            e,
            dataLevel: dataLevel,
            theme: theme,
            config: config,
          ),
        )
        .join(dataTheme.punctuation(', '));

    return '${dataTheme.brackets(start)}$body${dataTheme.brackets(end)}';
  }

  static String enumToString(
    Enum obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dotShorthand = '.${theme.formatValue(obj.name)}';

    return (config.enumDotShorthand ?? theme.common.enumDotShorthand)
        ? dotShorthand
        : '${obj.runtimeType}${theme.emphasis(dotShorthand)}';
  }

  static String doubleToString(
    double obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${switch (config.doubleFormat) {
        null => obj.toString(),
        final f => format('{:$f}', obj),
      }}'
      '${unitsToString(config.units, theme)}';

  static String intToString(
    int obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${switch (config.intFormat) {
        null => obj.toString(),
        final f => format('{:$f}', obj),
      }}'
      '${unitsToString(config.units, theme)}';

  static String stringToString(
    String obj, {
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${theme.styledOpeningQuote}'
      '${theme.formatValue(obj)}'
      '${theme.styledClosingQuote}'
      '${unitsToString(config.units, theme)}';

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
    LoggableConfig config = const LoggableConfig(),
  }) : _data = LoggableData._(
          TypeProp(Object, showName: false, showBrackets: false),
        ) {
    _data.prop(
      'obj',
      obj,
      showName: false,
      config: config,
      dataLevelCorrection: -1,
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
    int dataLevel,
    LogLevelTheme theme,
    LoggableResolvedConfig config,
  );
}

abstract interface class LoggableView {
  const factory LoggableView(Object? value, [String? units]) = _LoggableView;

  static LoggableView convert<T extends Object>(
    Object Function(T value, int dataLevel, LogLevelTheme theme) converter, [
    String? units,
  ]) =>
      _LoggableViewConvert<T>(converter, units);

  String toLogString(
    Object? value, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
  });
}

final class _LoggableView implements LoggableView {
  final Object? value;
  final String? units;

  const _LoggableView(this.value, [this.units]);

  /// Игнорируем переданное значение. Используем ранее заданное.
  @override
  String toLogString(
    Object? value, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
  }) =>
      switch (this.value) {
        null => 'null',
        final value => '$value${Loggable.unitsToString(units, theme)}',
      };
}

final class _LoggableViewConvert<T extends Object> implements LoggableView {
  final Object Function(T value, int dataLevel, LogLevelTheme theme) converter;
  final String? units;

  String? _result;

  _LoggableViewConvert(this.converter, [this.units]);

  @override
  String toLogString(
    Object? value, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
  }) =>
      switch (value) {
        null => 'null',
        T() => _result ??= '${converter(value, dataLevel, theme)}'
            '${Loggable.unitsToString(units, theme)}',
        _ => throw ArgumentError.value(value, 'value'),
      };
}

final class LoggableMultiView implements LoggableView {
  final List<LoggableView> views;
  final String separator;

  const LoggableMultiView(this.views, {this.separator = ' or '});

  @override
  String toLogString(
    Object? value, {
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
  }) {
    final dataTheme = theme.dataLevelTheme(dataLevel);

    return views
        .map(
          (e) => e.toLogString(
            value,
            dataLevel: dataLevel,
            theme: theme,
          ),
        )
        .join(dataTheme.punctuation(separator));
  }
}
