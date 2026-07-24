import 'dart:math' as math;

import 'package:ansi_escape_codes/extensions.dart';
import 'package:format/format.dart';
import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable_config.dart';
import 'loggable_json_config.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';

/// Вспомогательный класс, помогающий получить описание класса для логирования.
///
/// Позволяет:
///
/// - получить описание класса в виде строки, используя
///   [Loggable.objectToString] или [toString].
/// - получить описание класса в виде Json, используя [Loggable.objectToJson].
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
  ///     ..prop('b', obj.b, collectionMaxCount: 2),
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
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final depthTheme = theme.depthTheme(depth);

    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter(obj, theme, depth, config.toEffectiveConfig(theme.main));
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
        return listToString(obj, theme: theme, depth: depth, config: config);

      case Set<Object?>():
        return setToString(obj, theme: theme, depth: depth, config: config);

      case Iterable<Object?>():
        return iterableToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        );

      case Map<Object?, Object?>():
        return mapToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        );

      case Loggable():
        return obj
            .logClassInfo()
            .toLogString(theme: theme, depth: depth, config: config);

      case LoggableData():
        return obj.toLogString(
          theme: theme,
          depth: depth,
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
              '${theme.data.sectionStyle(key)}${theme.styledColon} $value',
          };
        }).join(depthTheme.punctuation(', '));

      default:
        return '${theme.formatValue(obj.toString())}'
            '${unitsToString(config.units, theme)}';
    }
  }

  static Object? objectToJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    switch (obj) {
      case null:
        return null;

      case bool() || int() || String():
        return switch (config.units) {
          null => obj,
          final units => {
              ':value': obj,
              ':units': units,
            },
        };

      case double():
        return doubleToJson(obj, config: config);

      case Enum():
        return enumToJson(obj, config: config);

      case List<Object?>():
        return listToJson(obj, config: config);

      case Set<Object?>():
        return setToJson(obj, config: config);

      case Iterable<Object?>():
        return iterableToJson(obj, config: config);

      case Map<Object?, Object?>():
        return mapToJson(obj, config: config);

      case Loggable():
        return obj.logClassInfo().toJson(config: config);

      case LoggableData():
        return obj.toJson(config: config);

      // case LoggableMultiData():
      //   return obj.data.entries.map((e) {
      //     final value = Loggable.objectToString(
      //       e.value,
      //       theme: theme,
      //       config: obj.config.merge(config),
      //     );

      //     return switch (e.key) {
      //       '' => value,
      //       final key =>
      //         '${theme.data.sectionStyle(key)}${theme.styledColon} $value',
      //     };
      //   }).join(depthTheme.punctuation(', '));

      default:
        return '$obj';
    }
  }

  /// Преобразует список в строку в виде `[₌₅ ₀:first, …, ₄:last]`.
  ///
  /// See [efficientLengthIterableToString].
  static String listToString(
    List<Object?> list, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        list,
        theme: theme,
        depth: depth,
        start: '[',
        end: ']',
        config: config,
      );

  static Object listToJson(
    List<Object?> list, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        list,
        'List',
        isList: true,
        config: config,
      );

  /// Преобразует множество в строку в виде `{₌₅ ₀:first, …, ₄:last}`.
  ///
  /// See [efficientLengthIterableToString].
  static String setToString(
    Set<Object?> set, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        set,
        theme: theme,
        depth: depth,
        start: '{',
        end: '}',
        config: config,
      );

  static Object setToJson(
    Set<Object?> set, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        set,
        'Set',
        config: config,
      );

  /// Преобразует коллекцию в строку в виде `(₌₅ ₀:first, …, ₄:last)`.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и эффективный доступ к последнему
  /// элементу.
  ///
  /// Если кол-во элементов в коллекции больше
  /// [LoggableConfig.collectionMaxCount] или длина строки больше
  /// [LoggableConfig.collectionMaxStringLength], то результат будет урезан.
  ///
  /// Возможные варианты:
  /// - 0 элементов
  ///   - (₌₀)
  /// - 1 элемент
  ///   - (₌₁ …)
  ///   - (₌₁ ₀:a)
  /// - 2 элемента
  ///   - (₌₂ …)
  ///   - (₌₂ ₀:a, …)
  ///   - (₌₂ ₀:a, ₁:b)
  /// - 3 элемента
  ///   - (₌₃ …)
  ///   - (₌₃ ₀:a, …)
  ///   - (₌₃ ₀:a, …, ₂:c)
  ///   - (₌₃ ₀:a, ₁:b, ₂:c)
  /// - 4 элемента
  ///   - (₌₄ …)
  ///   - (₌₄ ₀:a, …)
  ///   - (₌₄ ₀:a, …, ₃:d)
  ///   - (₌₄ ₀:a, ₁:b, …, ₃:d)
  ///   - (₌₄ ₀:a, ₁:b, ₂:c, ₃:d)
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.collectionMaxCount;
    final maxLength = config.collectionMaxStringLength;

    assert(maxCount == null || maxCount >= 0);
    assert(maxLength == null || maxLength > 0);
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    final depthTheme = theme.depthTheme(depth);

    final buf = StringBuffer(depthTheme.brackets(start));
    var reservedLength = start.length + end.length;

    // Добавляем размер коллекции.
    if (config.collectionShowCount ?? theme.main.collectionShowCount) {
      final count = iterable.length;
      final countText = '${theme.formatCount(count)}${count > 0 ? ' ' : ''}';
      reservedLength += countText.length;
      buf.write(depthTheme.description(countText));
    }

    _addEfficientLengthIterableItemsToBuf(
      buf,
      iterable,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
      showIndexes:
          config.collectionShowIndexes ?? theme.main.collectionShowIndexes,
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  static void _addEfficientLengthIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int? maxCount,
    required int? maxLength,
    required bool showIndexes,
  }) {
    String obj2str(Object? obj) => objectToString(
          obj,
          theme: theme,
          depth: depth + 1,
          config: config,
        );

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    // Если список пуст, то ничего не добавляем.
    final iterator = iterable.iterator;
    if (!iterator.moveNext()) {
      return;
    }

    final ellipsisStr = theme.main.ellipsis;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    final ellipsisSize = ellipsisStr.length;

    // Если не можем вывести ни одного элемента, выводим многоточие: (₌ₙ …)
    if (maxCount != null && maxCount <= 0) {
      buf.write(ellipsis);
      return;
    }

    const delimiterStr = ', ';
    late final delimiter = depthTheme.punctuation(delimiterStr);
    const delimiterSize = delimiterStr.length;

    // Если нет ограничений, выводим все элементы.
    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes
            ? iterable.indexed
                .map((e) => indexedObj2str(e.$1, e.$2))
                .join(delimiter)
            : iterable.map(obj2str).join(delimiter),
      );
      return;
    }

    late final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    final count = iterable.length;

    final first = showIndexes
        ? indexedObj2str(0, iterator.current)
        : obj2str(iterator.current);
    var l = first.lengthWithoutEscapeCodes;
    // Если первый элемент не помещается в строку, выводим многоточие: (₌ₙ …)
    // Но делаем это только в случае, когда размер элемента больше многоточия,
    // иначе лучше вывести сам элемент.
    if (!hasSpaceFor(l) && l > ellipsisSize) {
      buf.write(ellipsis);
      return;
    }

    // (₌₁ ₀:a)
    if (count == 1) {
      buf.write(first);
      return;
    }

    final last = showIndexes
        ? indexedObj2str(count - 1, iterable.last)
        : obj2str(iterable.last);
    l += delimiterSize;

    if (count == 2) {
      // (₌₂ ₀:a, ₁:b)
      if (hasSpaceFor(l + last.lengthWithoutEscapeCodes) &&
          (maxCount == null || maxCount > 1)) {
        buf
          ..write(first)
          ..write(delimiter)
          ..write(last);
        return;
      }

      // (₌₂ ₀:a, …)
      if (hasSpaceFor(l + ellipsisSize)) {
        buf
          ..write(first)
          ..write(delimiterAndEllipsis);
        return;
      }

      // (₌₂ …)
      buf.write(ellipsis);
      return;
    }

    // Если первый элемент с многоточием не помещаются в строку, то выводим
    // только многоточие: (₌ₙ …)
    if (!hasSpaceFor(l + ellipsisSize)) {
      buf.write(ellipsis);
      return;
    }

    buf.write(first);

    // Если можем вывести только один элемент, выводим в конце многоточие.
    if (maxCount != null && maxCount == 1) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    // Бронируем место для последнего элемента.
    l += last.lengthWithoutEscapeCodes;

    // Если последний элемент не помещается в строку, выводим вместо него
    // многоточие: (₌ₙ ₀:a, …)
    if (!hasSpaceFor(l)) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    (String, int)? bufferedItem;

    void writeBufferedItem() {
      if (bufferedItem != null) {
        buf
          ..write(delimiter)
          ..write(bufferedItem.$1);
      }
    }

    final effectiveCount =
        maxCount != null && maxCount < count ? maxCount : count;

    for (var i = 1; i < effectiveCount - 1; i++) {
      iterator.moveNext();
      final item = showIndexes
          ? indexedObj2str(i, iterator.current)
          : obj2str(iterator.current);
      final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;

      // Если новый элемент не вмещается, пытаемся вставить вместо него
      // многоточие.
      if (!hasSpaceFor(l + itemSize)) {
        // (₌₄ ₀:1, ₁:2, …, ₃:4)
        if (hasSpaceFor(l + delimiterSize + ellipsisSize)) {
          writeBufferedItem();
          buf
            ..write(delimiterAndEllipsis)
            ..write(delimiter)
            ..write(last);
          return;
        }

        // Если не удаётся вставить многоточие, изымаем последний элемент:
        // (₌₄ ₀:1, …, ₃:4). Если нечего изымать, то вставляем многоточие
        // вместо последнего элемента (такое возможно только для списка из 3-х
        // элементов): (₌₃ ₀:1, …)
        if (bufferedItem == null) {
          buf.write(delimiterAndEllipsis);
          return;
        }

        buf
          ..write(delimiterAndEllipsis)
          ..write(delimiter)
          ..write(last);

        return;
      }

      writeBufferedItem();
      bufferedItem = (item, itemSize);
      l += itemSize;
    }

    writeBufferedItem();
    if (count != effectiveCount) {
      buf.write(delimiterAndEllipsis);
    }
    buf
      ..write(delimiter)
      ..write(last);
  }

  /// Преобразует коллекцию в [Map] для дальнейшего преобразования в Json.
  ///
  /// Если коллекция является [List], сохраняется полностью и не содержит
  /// дополнительных данных, то результат будет возвращён в виде [List]:
  /// [a, b, c, d].
  ///
  /// В любом другом случае результат будет возвращён в виде [Map]:
  ///
  /// ```
  /// {
  ///   ":type": "Iterable"/"List"/"Set",
  ///   ":length": 4,
  ///   ":values": [a, d],
  ///   ":units": "m"
  /// }
  /// ```
  ///
  /// В этом случае последний элемент списка ":values" (если ":values" содержит
  /// более одного элемента) - это последний элемент исходной коллекции. Это
  /// сделано для того, чтобы сокращённую коллекцию развернуть в виде:
  /// (₌₄ ₀:a, …, ₃:d),
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и эффективный доступ к последнему
  /// элементу. Для иных случаев используйте [iterableToJson].
  static Object? efficientLengthIterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(iterable, 'Iterable', config: config);

  static Object _efficientLengthIterableToJson(
    Iterable<Object?> iterable,
    String type, {
    bool isList = false,
    required LoggableJsonConfig config,
  }) {
    // Не передаём units дочерним элементам.
    // ignore: avoid_redundant_argument_values
    late final itemConfig = config.copyWith(units: null);

    Object? obj2json(Object? obj) => objectToJson(
          obj,
          config: itemConfig,
        );

    var maxCount = config.collectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    if (maxCount == null || iterable.length <= maxCount) {
      final values = iterable.map(obj2json).toList();
      return isList && config.units == null
          ? values
          : {
              ':type': type,
              ':values': values,
              if (config.units case final units?) ':units': units,
            };
    }

    return {
      ':type': type,
      ':length': iterable.length,
      ':values': switch (maxCount) {
        0 => <Object>[],
        1 => [obj2json(iterable.first)],
        _ => [
            ...iterable.take(maxCount - 1).map(obj2json),
            obj2json(iterable.last),
          ],
      },
      if (config.units case final units?) ':units': units,
    };
  }

  /// Преобразует коллекцию в строку в виде `(₀:first, …)`.
  ///
  /// Если кол-во элементов в коллекции больше
  /// [LoggableConfig.collectionMaxCount] или длина строки больше
  /// [LoggableConfig.collectionMaxStringLength], то результат будет урезан.
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и имеют эффективный доступ к последнему
  /// элементу.
  static String iterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.collectionMaxCount;
    final maxLength = config.collectionMaxStringLength;

    assert(maxCount == null || maxCount >= 0);
    assert(maxLength == null || maxLength > 0);
    assert(!start.ansiHasEscapeCodes && !start.ansiHasControlCodes);
    assert(!end.ansiHasEscapeCodes && !end.ansiHasControlCodes);

    final depthTheme = theme.depthTheme(depth);

    final buf = StringBuffer(depthTheme.brackets(start));
    final reservedLength = start.length + end.length;

    _addIterableItemsToBuf(
      buf,
      iterable,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
      showIndexes:
          config.collectionShowIndexes ?? theme.main.collectionShowIndexes,
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  static void _addIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int? maxCount,
    required int? maxLength,
    required bool showIndexes,
  }) {
    String obj2str(Object? obj) => objectToString(
          obj,
          theme: theme,
          depth: depth + 1,
          config: config,
        );

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(obj)}';

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    final ellipsisStr = theme.main.ellipsis;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    final ellipsisSize = ellipsisStr.length;

    const delimiterStr = ', ';
    late final delimiter = depthTheme.punctuation(delimiterStr);
    const delimiterSize = delimiterStr.length;

    // Если нет ограничений, выводим все элементы.
    if (maxLength == null && maxCount == null) {
      buf.write(
        showIndexes
            ? iterable.indexed
                .map((e) => indexedObj2str(e.$1, e.$2))
                .join(delimiter)
            : iterable.map(obj2str).join(delimiter),
      );
      return;
    }

    late final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    final bufferedItems = <(String, int)>[];
    var isFirst = true;

    void writeBufferedItems() {
      for (final item in bufferedItems) {
        buf.write(item.$1);
        isFirst = false;
      }
      bufferedItems.clear();
    }

    var i = 0;
    var l = 0;
    for (final e in iterable) {
      if (maxCount != null && maxCount <= i) {
        writeBufferedItems();
        buf.write(isFirst ? ellipsis : delimiterAndEllipsis);
        break;
      }

      var item = showIndexes ? indexedObj2str(i, e) : obj2str(e);
      var itemSize = item.lengthWithoutEscapeCodes;
      if (i != 0) {
        item = '$delimiterStr$item';
        itemSize += delimiterSize;
      }

      // Если новый элемент не вмещается, пытаемся вставить вместо него
      // многоточие.
      if (!hasSpaceFor(l + itemSize) && itemSize > ellipsisSize) {
        // Пока не можем вставить многоточие, изымаем последний элемент
        while (!hasSpaceFor(l + delimiterSize + ellipsisSize) &&
            bufferedItems.isNotEmpty) {
          final lstItem = bufferedItems.removeLast();
          l -= lstItem.$2;
        }

        writeBufferedItems();
        buf.write(isFirst ? ellipsis : delimiterAndEllipsis);
        return;
      }

      if (bufferedItems.isNotEmpty && bufferedItems.first.$2 >= ellipsisSize) {
        writeBufferedItems();
      }
      bufferedItems.add((item, itemSize));

      l += itemSize;
      i++;
    }

    if (bufferedItems.isNotEmpty) {
      if (bufferedItems.first.$2 <= ellipsisSize || hasSpaceFor(l)) {
        writeBufferedItems();
      } else {
        buf.write(i == 1 ? ellipsis : delimiterAndEllipsis);
      }
    }
  }

  /// Преобразует коллекцию в [Map] для дальнейшего преобразования в Json.
  ///
  /// Результат будет возвращён в виде [Map]:
  ///
  /// ```
  /// {
  ///   ":type": "Iterable",
  ///   ":values": [a, b],
  ///   ":trimmed": true,
  ///   ":units": "m"
  /// }
  /// ```
  ///
  /// Параметр ":trimmed" присутствует, если коллекция обрезана. В этом случае
  /// список ":values" содержит первые элементы коллекции. Параметр ":trimmed"
  /// всегда равен `true`. В необрезанной коллекции он отсутствует.
  ///
  /// Обратите внимание на разницу с [efficientLengthIterableToJson]. И там,
  /// и там будет возвращена коллекция с типом "Iterable". Для полной коллекции
  /// результат будет совпадать, но в случае сокращения коллекции
  /// [efficientLengthIterableToJson] вернёт:
  ///
  /// ```
  /// {
  ///   ":type": "Iterable",
  ///   ":length": 4,
  ///   ":values": [a, b, d],
  /// }
  /// ```
  ///
  /// А [iterableToJson]:
  ///
  /// ```
  /// {
  ///   ":type": "Iterable",
  ///   ":values": [a, b, c],
  ///   ":trimmed": true,
  /// }
  /// ```
  ///
  /// В первом случае последний параметр списка ":values" - это последний
  /// элемент исходной коллекции (₌₄ ₀:a, ₁:b, …, ₃:d), а параметр ":length"
  /// содержит размер исходной коллекции. Во втором случае элементы списка
  /// ":values" - это первые элементы коллекции (₀:a, ₁:b, ₂:c, …), а параметр
  /// ":trimmed" указывает, что список не полон. [iterableToJson] не вычисляет
  /// длину коллекции.
  static Object iterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Не передаём units дочерним элементам.
    // ignore: avoid_redundant_argument_values
    late final itemConfig = config.copyWith(units: null);

    Object? obj2json(Object? obj) => objectToJson(
          obj,
          config: itemConfig,
        );

    var maxCount = config.collectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    Iterable<Object?> values;
    bool? trimmed;

    if (maxCount == null) {
      values = iterable;
    } else {
      final iterator = iterable.iterator;
      final list = <Object?>[];
      for (var i = 0; i < maxCount; i++) {
        if (!iterator.moveNext()) {
          trimmed = false;
          break;
        }

        list.add(iterator.current);
      }
      values = list;
      trimmed ??= iterator.moveNext();
    }

    return {
      ':type': 'Iterable',
      ':values': values.map(obj2json).toList(),
      if (trimmed ?? false) ':trimmed': true,
      if (config.units case final units?) ':units': units,
    };
  }

  static String mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    String obj2str(Object? obj) => objectToString(
          obj,
          depth: depth + 1,
          theme: theme,
          config: config,
        );

    final depthTheme = theme.depthTheme(depth);

    final key = switch (entry.key) {
      final String key => theme.formatValue(key),
      final key => obj2str(key),
    };

    return '${theme.data.keyStyle(key)}${depthTheme.punctuation(':')}'
        ' ${theme.data.valueStyle(obj2str(entry.value))}';
  }

  static String mapToString(
    Map<Object?, Object?> map, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '{',
    String end = '}',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final depthTheme = theme.depthTheme(depth);
    final body = map.entries
        .map(
          (e) => mapEntryToString(
            e,
            theme: theme,
            depth: depth,
            config: config,
          ),
        )
        .join(depthTheme.punctuation(', '));

    return '${depthTheme.brackets(start)}$body${depthTheme.brackets(end)}';
  }

  static Map<String, Object?> mapToJson(
    Map<Object?, Object?> map, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      map.map((k, v) {
        final key = switch (k) {
          String() => k,
          _ => k.toString(),
        };

        return MapEntry(key, objectToJson(v, config: config));
      });

  static String enumToString(
    Enum obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dotShorthand = '.${theme.formatValue(obj.name)}';
    final value = (config.enumDotShorthand ?? theme.main.enumDotShorthand)
        ? dotShorthand
        : '${obj.runtimeType}${theme.data.emphasis(dotShorthand)}';

    return '$value${unitsToString(config.units, theme)}';
  }

  static Object enumToJson(
    Enum obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      {
        ':enum': obj.runtimeType.toString(),
        ':name': obj.name,
        if (config.units case final units?) ':units': units,
      };

  static String doubleToString(
    double obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (obj.isFinite) {
      return '${switch (config.doubleFormat) {
        null => obj.toString(),
        final f => format('{:$f}', obj),
      }}'
          '${unitsToString(config.units, theme)}';
    }

    return obj.isNaN
        ? 'nan'
        : obj.isNegative
            ? '-inf'
            : 'inf';
  }

  static Object doubleToJson(
    double obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (obj.isFinite) {
      if (config.units case final units?) {
        return {':value': obj, ':units': units};
      }

      return obj;
    }

    return {
      ':type': 'double',
      ':value': obj.isNaN
          ? 'nan'
          : obj.isNegative
              ? '-inf'
              : 'inf',
      if (config.units case final units?) ':units': units,
    };
  }

  static String intToString(
    int obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${switch (config.intFormat) {
        null => obj.toString(),
        final f => format('{:$f}', obj),
      }}'
      '${unitsToString(config.units, theme)}';

  static String stringToString(
    String obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final stringInQuotes = config.stringInQuotes ?? theme.main.stringInQuotes;
    final openingQuote = stringInQuotes ? theme.styledOpeningQuote : '';
    final closingQuote = stringInQuotes ? theme.styledClosingQuote : '';

    return '$openingQuote${theme.formatValue(obj)}$closingQuote'
        '${unitsToString(config.units, theme)}';
  }

  static String unitsToString(
    String? units,
    LogTheme theme,
  ) =>
      units == null ? '' : theme.data.unitsStyle(theme.formatValue(units));
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
      depthCorrection: -1,
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
    LogTheme theme,
    int depth,
    LoggableEffectiveConfig config,
  );
}

abstract interface class LoggableView {
  const factory LoggableView(Object? value, [String? units]) = _LoggableView;

  static LoggableView convert<T extends Object>(
    Object Function(T value, LogTheme theme, int depth) converter, [
    String? units,
  ]) =>
      _LoggableViewConvert<T>(converter, units);

  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
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
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) =>
      switch (this.value) {
        null => 'null',
        final value => '$value${Loggable.unitsToString(units, theme)}',
      };
}

final class _LoggableViewConvert<T extends Object> implements LoggableView {
  final Object Function(T value, LogTheme theme, int depth) converter;
  final String? units;

  String? _result;

  _LoggableViewConvert(this.converter, [this.units]);

  @override
  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) =>
      switch (value) {
        null => 'null',
        T() => _result ??= '${converter(value, theme, depth)}'
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
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) {
    final depthTheme = theme.depthTheme(depth);

    return views
        .map(
          (e) => e.toLogString(
            value,
            theme: theme,
            depth: depth,
          ),
        )
        .join(depthTheme.punctuation(separator));
  }
}
