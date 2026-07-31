import 'dart:math' as math;

import 'package:ansi_escape_codes/extensions.dart';
import 'package:format/format.dart';
import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable_config.dart';
import 'loggable_json_config.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';
part 'log_value_sanitizer.dart';

/// A mixin describing how a class should look in logs.
///
/// Implement [collectLoggableData] to declare properties. Then:
///
/// - [Loggable.objectToString] (or [toString]) renders the object as
///   a themed string;
/// - [Loggable.objectToJson] renders it as a JSON-compatible structure;
/// - [logClassInfo] returns the property list for in-app UIs.
///
/// Cyclic structures are rendered as a cycle marker (`↺₂` — the
/// number is how many levels up the cycle points; configurable via
/// `LogMainTheme.cycleFormatter`/`cycleStyle`) instead of recursing
/// forever.
/// In JSON a cycle becomes `{":k": "cycle", ":up": 2}`.
abstract mixin class Loggable {
  static const _kindKey = ':k';
  static const _classKey = ':c';
  static const _lengthKey = ':l';
  static const _valueKey = ':v';
  static const _viewKey = ':view';
  static const _unitsKey = ':u';
  static const _propsKey = ':p';
  static const _bracketsKey = ':brackets';
  static const _trimKey = ':trim';
  static const _upKey = ':up';

  static final Map<Type, LoggableTypeConverter<Object?>> _converters = {};

  /// Глобальный санитайзер выводимых значений.
  ///
  /// `null` (по умолчанию) — вывод без обработки и без накладных
  /// расходов. Применяется в [objectToString] и [objectToJson], то есть
  /// ко ВСЕМ выводам: publisher'ам, in-app просмотрщику логов, экспорту
  /// сессий.
  ///
  /// Каждое значение обрабатывается ровно один раз, тем местом, которое
  /// знает его позицию (свойство, ключ [Map], индекс элемента).
  /// Правило получает [SanitizeContext] и возвращает исходное значение,
  /// замену или [Sanitize.drop].
  ///
  /// ```dart
  /// Loggable.sanitizer = (ctx) => switch (ctx.name) {
  ///   'password' || 'token' => Sanitize.drop,
  ///   _ => ctx.value,
  /// };
  /// ```
  static LogValueSanitizer? sanitizer;

  /// Сегменты пути к текущему значению: [String] — имя или ключ,
  /// [int] — индекс. Статический стек, как и [_visiting], чтобы не
  /// менять сигнатуры обходчиков.
  static final List<Object> _sanitizeSegments = <Object>[];

  static bool get _sanitizing => sanitizer != null;

  /// Применяет санитайзер к ребёнку, зная его позицию.
  ///
  /// Возвращает исходное значение (не трогали), замену или
  /// [Sanitize.drop]. Вызывать ровно один раз на значение: обходчики
  /// для не-корневых значений санитайзер не применяют.
  ///
  /// Пока не вызывается ниоткуда: обходчики Map/коллекций/свойств
  /// подключат его в следующих задачах (см. план).
  // ignore: unused_element
  static Object? _sanitizeChild(Object segment, String? name, Object? value) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return value;

    _sanitizeSegments.add(segment);
    try {
      return sanitizer(
        SanitizeContext._(
          name,
          value,
          _sanitizeSegments.length,
          _sanitizeSegments,
        ),
      );
    } finally {
      _sanitizeSegments.removeLast();
    }
  }

  /// Рендерит ребёнка, держа его сегмент в стеке пути, — чтобы у
  /// вложенных значений путь был полным.
  static T _withSegment<T>(Object segment, T Function() render) {
    if (!_sanitizing) return render();

    _sanitizeSegments.add(segment);
    try {
      return render();
    } finally {
      _sanitizeSegments.removeLast();
    }
  }

  /// Санитайз корня: у корня нет ни имени, ни сегмента пути.
  ///
  /// Возвращает [Sanitize.drop], замену или исходный объект. Повторного
  /// применения не происходит: рекурсивный вызов с заменой выполняется
  /// внутри [_withSegment], поэтому стек уже не пуст.
  static Object? _sanitizeRoot(Object? obj) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return obj;

    return sanitizer(SanitizeContext._(null, obj, 0, _sanitizeSegments));
  }

  /// Метод должен заполнить [data] описанием исследуемого класса.
  void collectLoggableData(LoggableData data);

  /// Оборачивает объект для возможности передачи параметров логирования.
  ///
  /// Имеет смысл использовать только для примитивных типов, enums, коллекций
  /// и [Loggable] с целью передачи параметров логирования. Для других
  /// объектов, не поддерживающих [Loggable] напрямую, используйте
  /// [Loggable.builder].
  ///
  /// В случае [Loggable] позволяет передать параметры, не установленные самим
  /// объектом.
  static LoggableWrapper from(
    Object? obj, {
    LoggableConfig config = const LoggableConfig(),
  }) =>
      LoggableWrapper(obj, config: config);

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
  static LoggableData builder(
    Object? value, {
    String? name,
    bool showName = true,
    bool showBrackets = true,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      _LoggableBuilder(
        value,
        name: name,
        showName: showName,
        showBrackets: showBrackets,
        config: config,
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
  ///
  /// log.d('map', data: Loggable.mapBuilder(config: LoggableConfig(units: 'm'))
  ///     ..prop('a', 1)
  ///     ..prop('b', 2)
  ///     ..prop('c', 3),
  /// );
  /// // map: {a: 1m, b: 2m, c: 3m}
  /// ```
  static LoggableData mapBuilder({
    LoggableConfig config = const LoggableConfig(),
  }) =>
      _LoggableMapBuilder(config: config);

  static void registerTypeConverter<T extends Object?>(
    LoggableTypeConverter<T> converter,
  ) {
    _converters[T] = converter as LoggableTypeConverter<Object?>;
  }

  /// Снимает конвертер по целевому типу [T] (тому же, что и при
  /// регистрации), а не по типу конвертера. Неверный [T] — тихий no-op.
  static void unregisterTypeConverter<T>() {
    _converters.remove(T);
  }

  @nonVirtual
  LoggableData logClassInfo() {
    final data = LoggableData._(TypeProp._(runtimeType));
    collectLoggableData(data);
    return data;
  }

  @override
  String toString() => logClassInfo().toLogString();

  /// Объекты, находящиеся в процессе форматирования в текущей цепочке
  /// рекурсии, — защита от циклических структур (по аналогии с
  /// `_toStringVisiting` в SDK).
  static final List<Object> _visiting = <Object>[];

  /// Примитивы не могут содержать ссылок и не требуют защиты от циклов.
  static bool _canContainCycle(Object obj) => switch (obj) {
        bool() ||
        num() ||
        String() ||
        Enum() ||
        DateTime() ||
        Duration() =>
          false,
        _ => true,
      };

  /// Индекс объекта в стеке форматирования или -1, если объект не в стеке.
  static int _visitingIndexOf(Object obj) {
    for (var i = 0; i < _visiting.length; i++) {
      if (identical(_visiting[i], obj)) return i;
    }

    return -1;
  }

  /// Количество уровней вверх до предка [ancestorIndex] в стеке.
  static int _cycleLevelsUp(int ancestorIndex) =>
      _visiting.length - ancestorIndex;

  /// Пользовательские ключи, начинающиеся с ':', экранируются дополнительным
  /// ':' — иначе они были бы неотличимы от служебных (':k', ':v', ...).
  static String _escapeServiceKey(String key) =>
      key.startsWith(':') ? ':$key' : key;

  /// Преобразует объект в строку, используя тему [theme] и конфигурацию
  /// [config].
  static String objectToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeRoot(obj);
      if (identical(sanitized, Sanitize.drop)) return '';
      if (!identical(sanitized, obj)) {
        // Сегмент-заглушка держит стек непустым: к замене санитайзер
        // повторно не применится.
        return _withSegment(
          '',
          () => objectToString(
            sanitized,
            theme: theme,
            depth: depth,
            config: config,
          ),
        );
      }
    }

    if (obj != null && _canContainCycle(obj)) {
      final ancestorIndex = _visitingIndexOf(obj);
      if (ancestorIndex != -1) {
        return theme.main.cycleStyle(
          theme.formatCycle(_cycleLevelsUp(ancestorIndex)),
        );
      }

      _visiting.add(obj);
      try {
        return _objectToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        );
      } finally {
        _visiting.removeLast();
      }
    }

    return _objectToString(obj, theme: theme, depth: depth, config: config);
  }

  static String _objectToString(
    Object? obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
    final depthTheme = theme.depthTheme(depth);

    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter.convertToData(obj).toLogString(
            theme: theme,
            depth: depth,
            config: config.toEffectiveConfig(theme.main),
          );
    }

    return switch (obj) {
      null => 'null',
      Enum() => _enumToString(obj, theme: theme, config: config),
      int() => _intToString(obj, theme: theme, config: config),
      double() => _doubleToString(obj, theme: theme, config: config),
      String() => _stringToString(obj, theme: theme, config: config),
      DateTime() => _dateTimeToString(obj, theme: theme),
      List<Object?>() =>
        listToString(obj, theme: theme, depth: depth, config: config),
      Set<Object?>() =>
        setToString(obj, theme: theme, depth: depth, config: config),
      Iterable<Object?>() => iterableToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        ),
      Map<Object?, Object?>() => _mapToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        ),
      Loggable() => obj
          .logClassInfo()
          .toLogString(theme: theme, depth: depth, config: config),
      LoggableData() => obj.toLogString(
          theme: theme,
          depth: depth,
          config: config,
        ),
      LoggableWrapper() => Loggable.objectToString(
          obj.data,
          theme: theme,
          depth: depth,
          config: obj.config.merge(config),
        ),
      LoggableMultiData() => obj.data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: theme,
            depth: depth,
            config: obj.config.merge(config),
          );

          return switch (e.key) {
            '' => value,
            final key =>
              '${theme.data.sectionStyle(key)}${theme.styledColon} $value',
          };
        }).join(depthTheme.punctuation(', ')),
      _ => theme.formatValue(obj.toString())
    };
  }

  static Object? objectToJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeRoot(obj);
      if (identical(sanitized, Sanitize.drop)) return null;
      if (!identical(sanitized, obj)) {
        // Сегмент-заглушка держит стек непустым: к замене санитайзер
        // повторно не применится.
        return _withSegment(
          '',
          () => objectToJson(sanitized, config: config),
        );
      }
    }

    if (obj != null && _canContainCycle(obj)) {
      final ancestorIndex = _visitingIndexOf(obj);
      if (ancestorIndex != -1) {
        return {_kindKey: 'cycle', _upKey: _cycleLevelsUp(ancestorIndex)};
      }

      _visiting.add(obj);
      try {
        return _objectToJson(obj, config: config);
      } finally {
        _visiting.removeLast();
      }
    }

    return _objectToJson(obj, config: config);
  }

  static Object? _objectToJson(
    Object? obj, {
    required LoggableJsonConfig config,
  }) {
    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter.convertToData(obj).toJson(config: config);
    }

    return switch (obj) {
      null || bool() || String() => obj,
      int() => _intToJson(obj, config: config),
      double() => _doubleToJson(obj, config: config),
      Enum() => _enumToJson(obj, config: config),
      DateTime() => _dateTimeToJson(obj),
      Duration() => _durationToJson(obj),
      List<Object?>() => listToJson(obj, config: config),
      Set<Object?>() => setToJson(obj, config: config),
      Iterable<Object?>() => iterableToJson(obj, config: config),
      Map<Object?, Object?>() => _mapToJson(obj, config: config),
      Loggable() => obj.logClassInfo().toJson(config: config),
      LoggableData() => obj.toJson(config: config),
      LoggableWrapper() => Loggable.objectToJson(
          obj.data,
          config: obj.config.mergeWithJsonConfig(config),
        ),
      LoggableMultiData() => {
          // Маркер типа — первым, как и в остальных служебных структурах.
          // Затереть его пользовательский ключ не может: ключи, начинающиеся
          // с ':', экранируются.
          _kindKey: 'multi',
          ...obj.data.map((k, v) {
            final value = Loggable.objectToJson(
              v,
              config: obj.config.mergeWithJsonConfig(config),
            );

            return MapEntry(_escapeServiceKey(k), value);
          }),
        },
      _ => {_viewKey: obj.toString()}
    };
  }

  /// Преобразует список в строку в виде `[₌₅ ₀:first, …, ₄:last]`.
  ///
  /// See [efficientLengthIterableToString].
  @visibleForTesting
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

  @visibleForTesting
  static Object listToJson(
    List<Object?> list, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        list,
        'list',
        isList: true,
        config: config,
      );

  /// Преобразует множество в строку в виде `{₌₅ ₀:first, …, ₄:last}`.
  ///
  /// See [efficientLengthIterableToString].
  @visibleForTesting
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

  @visibleForTesting
  static Object setToJson(
    Set<Object?> set, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        set,
        'set',
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
  @visibleForTesting
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
    final showCount =
        config.collectionShowCount ?? theme.main.collectionShowCount;
    final showIndexes =
        config.collectionShowIndexes ?? theme.main.collectionShowIndexes;

    final buf = StringBuffer(depthTheme.brackets(start));

    // В этом режиме длина и последний элемент не нужны.
    if (!showCount && maxCount == null && maxLength == null) {
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
      );
      buf.write(depthTheme.brackets(end));
      return buf.toString();
    }

    final count = iterable.length;
    var reservedLength = start.length + end.length;

    // Добавляем размер коллекции.
    if (showCount) {
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
      count: count,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
      showIndexes: showIndexes,
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
    required int count,
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

    const delimiterStr = ', ';
    late final delimiter = depthTheme.punctuation(delimiterStr);

    // Этот путь не требует ни длины коллекции, ни доступа к последнему
    // элементу.
    if (maxLength == null && maxCount == null) {
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
      );
      return;
    }

    if (count == 0) {
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

    const delimiterSize = delimiterStr.length;
    final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    // В сокращённой записи первый и последний элементы имеют приоритет.
    // Для промежуточных элементов нужен только один буфер: он позволяет
    // заменить последний добавленный элемент на многоточие, если строка
    // оказывается длиннее лимита.
    final iterator = iterable.iterator..moveNext();

    final first = showIndexes
        ? indexedObj2str(0, iterator.current)
        : obj2str(iterator.current);
    final firstSize = first.lengthWithoutEscapeCodes;
    // Если первый элемент не помещается в строку, выводим многоточие: (₌ₙ …)
    // Но делаем это только в случае, когда размер элемента больше многоточия,
    // иначе лучше вывести сам элемент.
    if (!hasSpaceFor(firstSize) && firstSize > ellipsisSize) {
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
    final lastSize = last.lengthWithoutEscapeCodes;

    if (count == 2) {
      // (₌₂ ₀:a, ₁:b)
      if (hasSpaceFor(firstSize + delimiterSize + lastSize) &&
          (maxCount == null || maxCount > 1)) {
        buf
          ..write(first)
          ..write(delimiter)
          ..write(last);
        return;
      }

      // (₌₂ ₀:a, …)
      if (hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
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
    if (!hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
      buf.write(ellipsis);
      return;
    }

    buf.write(first);

    // Если можем вывести только один элемент, выводим в конце многоточие.
    if (maxCount != null && maxCount == 1) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    final displayedCount = math.min(maxCount ?? count, count);

    // Бронируем место для разделителя и последнего элемента, а при обрезке
    // по количеству — ещё и для многоточия, которое будет выведено в конце.
    var usedSize = firstSize + delimiterSize + lastSize;
    if (displayedCount < count) {
      usedSize += delimiterSize + ellipsisSize;
    }

    // Если последний элемент не помещается в строку, выводим вместо него
    // многоточие: (₌ₙ ₀:a, …)
    if (!hasSpaceFor(usedSize)) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    String? bufferedItem;

    void writeBufferedItem() {
      if (bufferedItem case final item?) {
        buf
          ..write(delimiter)
          ..write(item);
      }
    }

    for (var i = 1; i < displayedCount - 1; i++) {
      iterator.moveNext();
      final item = showIndexes
          ? indexedObj2str(i, iterator.current)
          : obj2str(iterator.current);
      final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;

      // Если новый элемент не вмещается, пытаемся вставить вместо него
      // многоточие.
      if (!hasSpaceFor(usedSize + itemSize)) {
        // (₌₄ ₀:1, ₁:2, …, ₃:4)
        if (hasSpaceFor(usedSize + delimiterSize + ellipsisSize)) {
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
      bufferedItem = item;
      usedSize += itemSize;
    }

    writeBufferedItem();
    if (count != displayedCount) {
      buf.write(delimiterAndEllipsis);
    }
    buf
      ..write(delimiter)
      ..write(last);
  }

  static void _addAllIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required bool showIndexes,
  }) {
    String obj2str(Object? obj) => objectToString(
          obj,
          theme: theme,
          depth: depth + 1,
          config: config,
        );

    String indexedObj2str(int index, Object? obj) =>
        '${depthTheme.description(theme.formatIndex(index))}${obj2str(obj)}';

    final delimiter = depthTheme.punctuation(', ');
    buf.write(
      showIndexes
          ? iterable.indexed
              .map((item) => indexedObj2str(item.$1, item.$2))
              .join(delimiter)
          : iterable.map(obj2str).join(delimiter),
    );
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
  ///   ":k": "iterable"/"list"/"set",
  ///   ":l": 4,
  ///   ":v": [a, d],
  ///   ":u": "m"
  /// }
  /// ```
  ///
  /// В этом случае последний элемент списка ":v" (если ":v" содержит
  /// более одного элемента) - это последний элемент исходной коллекции. Это
  /// сделано для того, чтобы сокращённую коллекцию развернуть в виде:
  /// (₌₄ ₀:a, …, ₃:d),
  ///
  /// Метод предназначен только для коллекций, которые имеют эффективную
  /// длину (например, [List], [Set]) и эффективный доступ к последнему
  /// элементу. Для иных случаев используйте [iterableToJson].
  @visibleForTesting
  static Object? efficientLengthIterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(iterable, 'iterable', config: config);

  static Object _efficientLengthIterableToJson(
    Iterable<Object?> iterable,
    String type, {
    bool isList = false,
    required LoggableJsonConfig config,
  }) {
    // Не передаём units дочерним элементам.
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
              _kindKey: type,
              _valueKey: values,
              if (config.units case final units?) _unitsKey: units,
            };
    }

    return {
      _kindKey: type,
      _lengthKey: iterable.length,
      _valueKey: switch (maxCount) {
        0 => <Object>[],
        1 => [obj2json(iterable.first)],
        _ => [
            ...iterable.take(maxCount - 1).map(obj2json),
            obj2json(iterable.last),
          ],
      },
      if (config.units case final units?) _unitsKey: units,
    };
  }

  /// Преобразует коллекцию в строку в виде `(₀:first, …)`.
  ///
  /// Если кол-во элементов в коллекции больше
  /// [LoggableConfig.collectionMaxCount] или длина строки больше
  /// [LoggableConfig.collectionMaxStringLength], то результат будет урезан.
  ///
  /// Метод не вычисляет длину коллекции и не обращается к её последнему
  /// элементу, поэтому подходит и для однопроходных [Iterable]. При
  /// сокращении сохраняются только первые элементы, после которых добавляется
  /// многоточие. Если длина и последний элемент доступны эффективно,
  /// используйте [efficientLengthIterableToString].
  @visibleForTesting
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
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
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
        // Многоточие обрезки по количеству тоже должно влезать в бюджет
        // длины — при необходимости изымаем последние элементы.
        while (!hasSpaceFor(l + delimiterSize + ellipsisSize) &&
            bufferedItems.isNotEmpty) {
          final lastItem = bufferedItems.removeLast();
          l -= lastItem.$2;
        }

        writeBufferedItems();
        buf.write(isFirst ? ellipsis : delimiterAndEllipsis);
        break;
      }

      var item = showIndexes ? indexedObj2str(i, e) : obj2str(e);
      var itemSize = item.lengthWithoutEscapeCodes;
      if (i != 0) {
        item = '$delimiter$item';
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
  /// `{":k": "iterable", ":v": [a, b], ":trim": true, ":u": "m"}`.
  ///
  /// Параметр ":trim" присутствует, если коллекция обрезана. В этом случае
  /// список ":v" содержит первые элементы коллекции. Параметр ":trim"
  /// всегда равен `true`. В необрезанной коллекции он отсутствует.
  ///
  /// Обратите внимание на разницу с [efficientLengthIterableToJson]. И там,
  /// и там будет возвращена коллекция с типом "iterable". Для полной коллекции
  /// результат будет совпадать, но в случае сокращения коллекции
  /// [efficientLengthIterableToJson] вернёт:
  /// `{":k": "iterable", ":l": 4, ":v": [a, b, d]}`.
  ///
  /// А [iterableToJson]:
  /// `{":k": "iterable", ":v": [a, b, c], ":trim": true}`.
  ///
  /// В первом случае последний параметр списка ":v" - это последний элемент
  /// исходной коллекции (₌₄ ₀:a, ₁:b, …, ₃:d), а параметр ":l" - размер
  /// исходной коллекции. Во втором случае элементы списка ":v" - это первые
  /// элементы коллекции (₀:a, ₁:b, ₂:c, …), а параметр ":trim" указывает, что
  /// список не полон. [iterableToJson] не вычисляет длину коллекции.
  @visibleForTesting
  static Object iterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Не передаём units дочерним элементам.
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
      _kindKey: 'iterable',
      _valueKey: values.map(obj2json).toList(),
      if (trimmed ?? false) _trimKey: true,
      if (config.units case final units?) _unitsKey: units,
    };
  }

  static String _mapEntryToString(
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

  static String _mapToString(
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
          (e) => _mapEntryToString(
            e,
            theme: theme,
            depth: depth,
            config: config,
          ),
        )
        .join(depthTheme.punctuation(', '));

    return '${depthTheme.brackets(start)}$body${depthTheme.brackets(end)}';
  }

  static Map<String, Object?> _mapToJson(
    Map<Object?, Object?> map, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Не передаём units дочерним элементам.
    late final itemConfig = config.copyWith(units: null);

    final result = map.map((k, v) {
      final key = _escapeServiceKey(
        switch (k) {
          String() => k,
          _ => k.toString(),
        },
      );

      return MapEntry(key, objectToJson(v, config: itemConfig));
    });

    return switch (config.units) {
      null => result,
      final units => {...result, _unitsKey: units}
    };
  }

  static String _enumToString(
    Enum obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dotShorthand = '.${theme.formatValue(obj.name)}';
    return (config.enumDotShorthand ?? theme.main.enumDotShorthand)
        ? dotShorthand
        : '${obj.runtimeType}${theme.data.emphasis(dotShorthand)}';
  }

  /// Преобразует Enum в [Map] для дальнейшего преобразования в Json.
  ///
  /// Результат возвращается в виде:

  static Map<String, Object?> _enumToJson(
    Enum obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      {
        _classKey: obj.runtimeType.toString(),
        _valueKey: obj.name,
      };

  static Map<String, Object?> _dateTimeToJson(DateTime obj) => {
        _kindKey: 'datetime',
        _valueKey: obj.toIso8601String(),
      };

  static Map<String, Object?> _durationToJson(Duration obj) => {
        _kindKey: 'duration',
        _valueKey: obj.toString(),
      };

  static String _intToString(
    int obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${switch (config.intFormat) {
        null => obj.toString(),
        final f => format('{:$f}', obj),
      }}'
      '${unitsToString(config.units, theme)}';

  static String _doubleToString(
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

    // См. комментарий в [_doubleToJson]: для nan/inf units не показываются.
    return obj.isNaN
        ? 'nan'
        : obj.isNegative
            ? '-inf'
            : 'inf';
  }

  static Object _intToJson(
    int obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      switch (config.units) {
        null => obj,
        final units => {
            _valueKey: obj,
            _unitsKey: units,
          },
      };

  static Object _doubleToJson(
    double obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (obj.isFinite) {
      if (config.units case final units?) {
        return {_valueKey: obj, _unitsKey: units};
      }

      return obj;
    }

    // Units — чисто визуальная сущность: для nan/inf не показываются
    // ни в строке, ни в JSON.
    return {
      _kindKey: 'double',
      _valueKey: obj.isNaN
          ? 'nan'
          : obj.isNegative
              ? '-inf'
              : 'inf',
    };
  }

  static String _stringToString(
    String obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final stringInQuotes = config.stringInQuotes ?? theme.main.stringInQuotes;

    return stringInQuotes
        ? '${theme.styledOpeningQuote}'
            '${theme.formatValue(obj)}'
            '${theme.styledClosingQuote}'
        : theme.formatValue(obj);
  }

  static String _dateTimeToString(
    DateTime obj, {
    LogTheme theme = LogTheme.noColors,
  }) =>
      theme.formatValue(obj.toIso8601String());

  static String unitsToString(
    String? units,
    LogTheme theme,
  ) =>
      units == null ? '' : theme.data.unitsStyle(theme.formatValue(units));
}

final class LoggableWrapper {
  final Object? data;
  final LoggableConfig config;

  LoggableWrapper(
    this.data, {
    this.config = const LoggableConfig(),
  });

  Object? toJson({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      Loggable.objectToJson(
        data,
        config: this.config.mergeWithJsonConfig(config),
      );

  @override
  String toString() => Loggable.objectToString(data, config: config);
}

/// Конвертер стороннего типа [T] в [LoggableData].
///
/// Библиотека вызывает только [convertToData]; полученный [LoggableData]
/// сам умеет и в строку, и в JSON. Конвертер подбирается строго по
/// `runtimeType` — для наследников [T] он не применяется.
abstract interface class LoggableTypeConverter<T extends Object?> {
  LoggableData convertToData(T obj);
}

abstract interface class LoggableView {
  const factory LoggableView(Object? value, {String? units}) = _LoggableView;

  static LoggableView convert<T extends Object>(
    Object Function(T value, LogTheme theme, int depth) converter, {
    String? units,
  }) =>
      _LoggableViewConvert<T>(converter, units);

  Object? toJson(Object? value);

  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  });
}

final class _LoggableView implements LoggableView {
  final Object? value;
  final String? units;

  const _LoggableView(this.value, {this.units});

  /// Игнорируем переданное значение. Используем ранее заданное.
  @override
  Object? toJson(Object? _) {
    final v = value;

    return switch (v) {
      null => null,
      bool() || num() => switch (units) {
          null => v,
          final units => {
              Loggable._valueKey: v,
              Loggable._unitsKey: units,
            }
        },
      _ => {
          Loggable._viewKey: v.toString(),
          if (units case final units?) Loggable._unitsKey: units,
        },
    };
  }

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

  _LoggableViewConvert(this.converter, this.units);

  @override
  Object? toJson(Object? value) {
    switch (value) {
      case null:
        return null;

      case T():
        final v = converter(value, LogTheme.noColors, 0);

        return switch (v) {
          bool() || num() => switch (units) {
              null => v,
              final units => {
                  Loggable._valueKey: v,
                  Loggable._unitsKey: units,
                },
            },
          final _ => {
              Loggable._viewKey: v.toString(),
              if (units case final units?) Loggable._unitsKey: units,
            },
        };

      default:
        throw ArgumentError.value(value, 'value');
    }
  }

  @override
  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) =>
      switch (value) {
        null => 'null',
        T() => '${converter(value, theme, depth)}'
            '${Loggable.unitsToString(units, theme)}',
        _ => throw ArgumentError.value(value, 'value'),
      };
}

final class LoggableMultiView implements LoggableView {
  final List<LoggableView> views;
  final String separator;

  const LoggableMultiView(this.views, {this.separator = '/'});

  @override
  Object? toJson(Object? value) => {
        Loggable._kindKey: 'multi-view',
        Loggable._valueKey: [for (final view in views) view.toJson(value)],
      };

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
