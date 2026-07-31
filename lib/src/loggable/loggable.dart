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
  ///
  /// Правило обязано быть чистой функцией от [SanitizeContext]: без
  /// побочных эффектов (сам факт вызова не гарантирует, что значение
  /// будет напечатано, — см. спеку, «Циклы, лимиты, ленивость») и без
  /// рендеринга. Рендеринг — это не только явные
  /// [objectToString]/[objectToJson], но и интерполяция `'${ctx.value}'`
  /// либо `ctx.value.toString()` для [Loggable], [LoggableData],
  /// [LoggableWrapper] и [LoggableMultiData]: их `toString` заходит в те
  /// же обходчики, из которых правило и было вызвано. Логировать изнутри
  /// правила тоже нельзя.
  ///
  /// Ключ [Map] правилу не предлагается: правило получает значение
  /// записи, а ключ видит как [SanitizeContext.name] и часть
  /// [SanitizeContext.path]. Секрет в самом ключе
  /// (`{'ann@example.com': {...}}`) заменой не вычистить — правило по
  /// имени может только выбросить запись целиком через [Sanitize.drop].
  ///
  /// Значения ВНУТРИ объекта-ключа предлагаются только там, где рендер
  /// ключа заходит в обходчики: в строковом выводе — всегда, в JSON —
  /// только для [Loggable] и [LoggableWrapper]. Любой другой ключ
  /// [objectToJson] рисует через `key.toString()`, мимо обходчиков, —
  /// поэтому секрет внутри обычного контейнера-ключа
  /// (`{{'pw': 'hunter2'}: 'primary'}`) на консоли замаскируется
  /// (`{{pw: "<masked>"}: "primary"}`), а в [objectToJson] — и, значит, в
  /// JSONL-файле — уцелеет (`{"{pw: hunter2}": "primary"}`). Убрать его
  /// оттуда можно только выбросив запись целиком. Там же, где содержимое
  /// ключа предлагается, оно идёт под путём КОНТЕЙНЕРА, а не записи: в
  /// `{'acc': {Account('DE89'): 'x'}}` свойство ключа придёт как
  /// `acc.iban`, тогда как сама запись — `acc.Account(iban: "DE89")`.
  ///
  /// Для нестрокового ключа [SanitizeContext.name] — это ключ в том виде,
  /// в каком его рисует ИМЕННО ЭТОТ вывод: строковый — обходчиком и
  /// темой (`[₌₂ ₀:1, ₁:2]`, `.admin`), JSON — через `key.toString()`
  /// (`[1, 2]`, `Role.admin`). Формы разные, а строковая ещё и зависит от
  /// темы, поэтому правило по тексту ключа сработает в одном выводе и
  /// пропустит запись в другом: такие записи редактируйте по значению
  /// либо выбрасывайте целиком.
  ///
  /// Санитайзер — статическое поле, то есть живёт в пределах одного
  /// изолята: правило, установленное в главном изоляте, не применится к
  /// логам, отрисованным в порождённом, — там его нужно установить
  /// заново.
  ///
  /// Область действия — только значения ВНУТРИ `data`. `message`, `error`
  /// и `stackTrace` через обходчики [objectToString]/[objectToJson] не
  /// проходят: принтер печатает `log.message` как есть и `error` через
  /// `toString()`, `FileLogCodec` пишет их так же, — так что санитайзер
  /// эти поля не видит и подменить не может. Замаскировать их или
  /// отбросить лог целиком — задача `Logger.transformer`.
  ///
  /// Бросать из правила нельзя: fail-closed здесь нет, в отличие от
  /// `Logger.transformer`. Исключение уходит в тот publisher, который в
  /// этот момент рендерил: `FileLogStorage` отдаст его своему `onError` и
  /// запишет fallback-строку без данных, а `ConsoleLogPrinter` его не
  /// ловит — исключение покинет `publish()`, и `MultiPublisher` его
  /// изолирует, но принтер сам по себе пробросит его в точку логирования.
  static LogValueSanitizer? sanitizer;

  /// Сегменты пути к текущему значению: [String] — имя или ключ,
  /// [int] — индекс. Статический стек, как и [_visiting], чтобы не
  /// менять сигнатуры обходчиков.
  static final List<Object> _sanitizeSegments = <Object>[];

  static bool get _sanitizing => sanitizer != null;

  /// Сегмент-заглушка корневой позиции: держит [_sanitizeSegments]
  /// непустым, оставаясь вне пути и вне счёта глубины.
  ///
  /// Ставится дважды (см. [_sanitizeRoot]): на время вызова правила для
  /// корня — иначе рендер изнутри правила снова попал бы в корневую
  /// ветку и зациклился, — и на повторный рендер значения, заменившего
  /// корень, — иначе санитайзер сработал бы на замену второй раз.
  ///
  /// Собственный приватный тип, а не `const Object()`: два разных
  /// `const Object()` идентичны, и маркер спутался бы с любым другим
  /// (см. [Prop._notSanitized]).
  static const Object _rootGuardSegment = _SanitizeGuardSegment();

  /// Сколько заглушек сейчас в [_sanitizeSegments] (0 или 1) —
  /// чтобы [_sanitizeChild] и [SanitizeContext.path] могли исключить их
  /// за O(1), не сканируя стек на каждый узел.
  static int _placeholderCount = 0;

  /// Применяет санитайзер к ребёнку, зная его позицию.
  ///
  /// Возвращает исходное значение (не трогали), замену или
  /// [Sanitize.drop]. Вызывать ровно один раз на значение: обходчики
  /// для не-корневых значений санитайзер не применяют.
  ///
  /// [LoggableWrapper] разворачивается: правилу показывается завёрнутое
  /// значение, а не обёртка, — как и в корне (см. [objectToString]),
  /// иначе `Loggable.from(password)` в позиции свойства, записи [Map]
  /// или элемента коллекции прошёл бы мимо правил по содержимому. Если
  /// правило вернуло содержимое без изменений, рендерится ИСХОДНАЯ
  /// обёртка — её `config` должен уцелеть; замена рендерится как обычное
  /// значение (так же, как в правиле для `view`).
  static Object? _sanitizeChild(Object segment, String? name, Object? value) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return value;

    var offered = value;
    while (offered is LoggableWrapper) {
      offered = offered.data;
    }

    final Object? result;
    _sanitizeSegments.add(segment);
    try {
      result = sanitizer(
        SanitizeContext._(
          name,
          offered,
          _sanitizeSegments.length - _placeholderCount,
          _sanitizeSegments,
        ),
      );
    } finally {
      _sanitizeSegments.removeLast();
    }

    return identical(result, offered) ? value : result;
  }

  /// Рендерит ребёнка, держа его сегмент в стеке пути, — чтобы у
  /// вложенных значений путь был полным.
  static T _withSegment<T>(Object segment, T Function() render) {
    if (!_sanitizing) return render();

    final isPlaceholder = identical(segment, _rootGuardSegment);
    _sanitizeSegments.add(segment);
    if (isPlaceholder) _placeholderCount++;
    try {
      return render();
    } finally {
      if (isPlaceholder) _placeholderCount--;
      _sanitizeSegments.removeLast();
    }
  }

  /// `true`, если [value] — маркер [Sanitize.drop] от АКТИВНОГО
  /// санитайзера.
  ///
  /// Без установленного санитайзера [Sanitize.drop] — обычные
  /// пользовательские данные: без этой проверки, будучи публичным
  /// API, он мог бы случайно затереть чужую запись в выводе. Общий
  /// предикат, чтобы обходчики Map/коллекций/свойств не повторяли эту
  /// проверку (и потенциальную ошибку) каждый на свой лад.
  static bool _isDropped(Object? value) =>
      _sanitizing && identical(value, Sanitize.drop);

  /// Санитайз корня: у корня нет ни имени, ни сегмента пути.
  ///
  /// Возвращает [Sanitize.drop], замену или исходный объект. Повторного
  /// применения не происходит: рекурсивный вызов с заменой выполняется
  /// внутри [_withSegment], поэтому стек уже не пуст.
  ///
  /// Само правило тоже вызывается под заглушкой: без неё рендер изнутри
  /// правила (в том числе неявный — `'${ctx.value}'` для [Loggable] и
  /// компании) снова увидел бы пустой стек, снова позвал бы правило и
  /// ушёл бы в бесконечную рекурсию. Правилу рендерить по-прежнему
  /// нельзя (см. [sanitizer]), но зависание — слишком дорогая цена за
  /// нарушение контракта.
  static Object? _sanitizeRoot(Object? obj) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return obj;

    return _withSegment(
      _rootGuardSegment,
      () => sanitizer(SanitizeContext._(null, obj, 0, _sanitizeSegments)),
    );
  }

  /// Предлагает правилу КОРНЕВОЕ значение и, если правило его тронуло,
  /// возвращает готовый строковый вывод.
  ///
  /// `null` означает «рендерить самому вызывающему»: правило значение не
  /// тронуло, санитайзера нет, либо это вообще не корень — стек
  /// сегментов не пуст, а значит значение уже предложено правилу по
  /// своей позиции. Пустая строка — [Sanitize.drop], всё остальное —
  /// отрисованная замена.
  ///
  /// ЕДИНСТВЕННАЯ точка корневого предложения для строкового вывода. Её
  /// зовёт [objectToString], и её же ОБЯЗАНЫ звать альтернативные
  /// рендереры multi-data (`LoggableMultiData.toString` и `LogMessage` в
  /// принтере): они входят сразу в [forEachMultiDataEntry], поэтому без
  /// этого вызова корень не предлагался бы правилу вовсе — на консоли
  /// печаталось бы то, что в JSONL-файле правило выбрасывает.
  @internal
  static String? sanitizeRootToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) return null;

    final sanitized = _sanitizeRoot(obj);
    if (identical(sanitized, Sanitize.drop)) return '';
    if (identical(sanitized, obj)) return null;

    // Сегмент-заглушка держит стек непустым: к замене санитайзер
    // повторно не применится. В depth/path он не учитывается.
    return _withSegment(
      _rootGuardSegment,
      () => objectToString(
        sanitized,
        theme: theme,
        depth: depth,
        config: _rootConfig(obj, config),
      ),
    );
  }

  /// Конфигурация, которой рендерится ЗАМЕНА корня.
  ///
  /// Замена встаёт на место контейнера, поэтому форматируется его
  /// настройками: у [LoggableMultiData] свой `config`, и обходчик его не
  /// видит — ему передан только окружающий. Без этого мержа рендереры
  /// расходились бы: `LoggableMultiData.toString` и `LogMessage`
  /// передают сюда `data.config` сами (для них мерж идемпотентен), а
  /// [objectToString]/[objectToJson] печатали бы замену без units и
  /// лимитов контейнера — то есть JSONL расходился бы с консолью.
  static LoggableConfig _rootConfig(Object? obj, LoggableConfig config) =>
      obj is LoggableMultiData ? obj.config.merge(config) : config;

  /// Рендерит КОРНЕВОЕ значение и сообщает, отбросило ли его правило.
  ///
  /// Принтеру мало готового текста: пустая строка бывает и законным
  /// рендером (пустой [LoggableMultiData], `Loggable.builder` без
  /// свойств), и результатом [Sanitize.drop], — а двоеточие блока данных
  /// должно пропадать только во втором случае. Снаружи их не различить:
  /// корневое предложение живёт внутри [sanitizeRootToString], а звать её
  /// второй раз нельзя — правило сработало бы на корень дважды. Поэтому
  /// сигнал отдаёт тот, кто предложил.
  ///
  /// Корень предлагается ровно один раз: если правило его не тронуло,
  /// значение рендерится под заглушкой, и [objectToString] не предложит
  /// его повторно.
  @internal
  static ({String text, bool dropped}) renderRoot(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
  }) {
    if (!_sanitizing) {
      return (text: objectToString(obj, theme: theme), dropped: false);
    }

    // Обёртка разворачивается ДО корневого предложения — как в
    // [objectToString]: правилу показывается завёрнутое значение, а не
    // упаковка параметров рендера.
    var value = obj;
    var config = const LoggableConfig();
    while (value is LoggableWrapper) {
      config = value.config.merge(config);
      value = value.data;
    }

    if (sanitizeRootToString(value, theme: theme, config: config)
        case final rendered?) {
      return (text: rendered, dropped: rendered.isEmpty);
    }

    return (
      text: _withSegment(
        _rootGuardSegment,
        () => objectToString(value, theme: theme, config: config),
      ),
      dropped: false,
    );
  }

  /// Обходит записи [LoggableMultiData], применяя санитайзер к каждой по
  /// её ключу ровно один раз, и вызывает [render] для уцелевших.
  ///
  /// ЕДИНСТВЕННАЯ точка санитайза записей multi-data. Секции рисуют
  /// четыре разных места ([_multiDataToString], [_multiDataToJson],
  /// `LoggableMultiData.toString` и `LogMessage` в принтере — у каждого
  /// свои разделители и переносы строк), но позицию значения знает
  /// только этот хелпер: рендерер, обошедший его стороной, отдал бы
  /// значение обходчику как КОРЕНЬ — без имени, без сегмента пути и мимо
  /// правила.
  ///
  /// Корень — не забота этого хелпера: рендереры, для которых multi-data
  /// и есть корневое значение, обязаны сначала позвать
  /// [sanitizeRootToString].
  ///
  /// [render] получает уже санитизированное значение и обязан рендерить
  /// его только внутри вызова: сегмент ключа держится в стеке пути,
  /// чтобы у вложенных значений путь был полным.
  @internal
  static void forEachMultiDataEntry(
    LoggableMultiData data,
    void Function(String key, Object? value) render,
  ) {
    for (final entry in data.data.entries) {
      final sanitized = _sanitizeChild(entry.key, entry.key, entry.value);
      if (_isDropped(sanitized)) continue;

      _withSegment(entry.key, () => render(entry.key, sanitized));
    }
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
    // LoggableWrapper — прозрачная упаковка параметров рендера, а не
    // самостоятельное значение. Разворачиваем её до проверки корня: иначе
    // санитайзер увидел бы обёртку и её содержимое как два разных корня
    // (сам объект-обёртку, а затем ещё раз данные внутри неё).
    if (obj is LoggableWrapper) {
      return objectToString(
        obj.data,
        theme: theme,
        depth: depth,
        config: obj.config.merge(config),
      );
    }

    // Корневое предложение — в общем хелпере: его же зовут рендереры
    // multi-data, не проходящие через этот обходчик.
    if (sanitizeRootToString(obj, theme: theme, depth: depth, config: config)
        case final rendered?) {
      return rendered;
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
      // LoggableWrapper разворачивается прозрачно в [objectToString] до
      // попадания сюда (см. комментарий там) — эта ветка недостижима.
      LoggableMultiData() => _multiDataToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        ),
      _ => theme.formatValue(obj.toString())
    };
  }

  static String _multiDataToString(
    LoggableMultiData obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
    final depthTheme = theme.depthTheme(depth);
    final entryConfig = obj.config.merge(config);
    final parts = <String>[];

    forEachMultiDataEntry(obj, (key, value) {
      final text = objectToString(
        value,
        theme: theme,
        depth: depth,
        config: entryConfig,
      );

      parts.add(
        key.isEmpty
            ? text
            : '${theme.data.sectionStyle(key)}${theme.styledColon} $text',
      );
    });

    return parts.join(depthTheme.punctuation(', '));
  }

  static Object? objectToJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // См. комментарий в [objectToString]: обёртка разворачивается до
    // проверки корня, чтобы санитайзер не увидел два корня вместо одного.
    if (obj is LoggableWrapper) {
      return objectToJson(
        obj.data,
        config: obj.config.mergeWithJsonConfig(config),
      );
    }

    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeRoot(obj);
      if (identical(sanitized, Sanitize.drop)) return null;
      if (!identical(sanitized, obj)) {
        // Сегмент-заглушка держит стек непустым: к замене санитайзер
        // повторно не применится. В depth/path он не учитывается.
        // Конфигурация — как в [sanitizeRootToString] (см. [_rootConfig]):
        // замена корня форматируется настройками контейнера, иначе JSON
        // разошёлся бы со строковым выводом.
        return _withSegment(
          _rootGuardSegment,
          () => objectToJson(
            sanitized,
            config: obj is LoggableMultiData
                ? obj.config.mergeWithJsonConfig(config)
                : config,
          ),
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
      // LoggableWrapper разворачивается прозрачно в [objectToJson] до
      // попадания сюда (см. комментарий там) — эта ветка недостижима.
      LoggableMultiData() => _multiDataToJson(obj, config: config),
      _ => {_viewKey: obj.toString()}
    };
  }

  /// Санитайз записей `LoggableMultiData` по ключу для JSON; собираем
  /// циклом (а не `Map.map`), чтобы уметь пропускать записи,
  /// санитизированные до [Sanitize.drop].
  static Map<String, Object?> _multiDataToJson(
    LoggableMultiData obj, {
    required LoggableJsonConfig config,
  }) {
    final entryConfig = obj.config.mergeWithJsonConfig(config);

    // Маркер типа — первым, как и в остальных служебных структурах.
    // Затереть его пользовательский ключ не может: ключи, начинающиеся
    // с ':', экранируются.
    final result = <String, Object?>{_kindKey: 'multi'};
    forEachMultiDataEntry(obj, (key, value) {
      result[_escapeServiceKey(key)] = objectToJson(value, config: entryConfig);
    });

    return result;
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
    // Санитайз элемента коллекции: позиция — индекс в исходной
    // коллекции (не порядковый номер среди выведенных — иначе после
    // обрезки путь врал бы), имени нет. Sanitize.drop в этой позиции не
    // убирает элемент (иначе разъехались бы длина и бюджет обрезки), а
    // превращается в маркер '<dropped>'.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(index, obj)}';

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
        : obj2str(0, iterator.current);
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

    // Последний элемент рендерится лениво: при collectionMaxCount == 1
    // он в вывод не попадает, а рендер — это ещё и санитайз, то есть
    // правилу предлагалось бы отсечённое лимитом значение. Спека
    // оговаривает такой эффект только для бюджета по ДЛИНЕ (там размер
    // кандидата иначе не измерить), но не для лимита по количеству.
    late final last = showIndexes
        ? indexedObj2str(count - 1, iterable.last)
        : obj2str(count - 1, iterable.last);
    late final lastSize = last.lengthWithoutEscapeCodes;

    if (count == 2) {
      // (₌₂ ₀:a, ₁:b). Проверка лимита — первой: иначе `lastSize`
      // посчитался бы и при maxCount == 1, где последнего элемента в
      // выводе нет.
      if ((maxCount == null || maxCount > 1) &&
          hasSpaceFor(firstSize + delimiterSize + lastSize)) {
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
          : obj2str(i, iterator.current);
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
    // См. комментарий в [_addEfficientLengthIterableItemsToBuf]: индекс —
    // позиция в исходной коллекции, drop = маркер, а не удаление.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String indexedObj2str(int index, Object? obj) =>
        '${depthTheme.description(theme.formatIndex(index))}'
        '${obj2str(index, obj)}';

    final delimiter = depthTheme.punctuation(', ');
    buf.write(
      iterable.indexed
          .map(
            (item) => showIndexes
                ? indexedObj2str(item.$1, item.$2)
                : obj2str(item.$1, item.$2),
          )
          .join(delimiter),
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

    // Санитайз элемента: индекс — позиция в исходной коллекции.
    // Sanitize.drop заменяется маркером, а не убирает элемент, — иначе
    // разъедутся ':l' (длина) и фактическое число элементов в ':v'.
    Object? obj2json(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToJson(
          _isDropped(value) ? '<dropped>' : value,
          config: itemConfig,
        ),
      );
    }

    var maxCount = config.collectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    if (maxCount == null || iterable.length <= maxCount) {
      final values =
          iterable.indexed.map((item) => obj2json(item.$1, item.$2)).toList();
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
        1 => [obj2json(0, iterable.first)],
        _ => [
            ...iterable
                .take(maxCount - 1)
                .indexed
                .map((item) => obj2json(item.$1, item.$2)),
            obj2json(iterable.length - 1, iterable.last),
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
    // См. комментарий в [_addEfficientLengthIterableItemsToBuf]: индекс —
    // позиция в исходной коллекции, drop = маркер, а не удаление.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(index, obj)}';

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

      var item = showIndexes ? indexedObj2str(i, e) : obj2str(i, e);
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

    // Санитайз элемента: индекс — позиция в [values]. Метод обрезает
    // только хвост (не пропускает элементы из середины), поэтому она
    // всегда совпадает с позицией в исходной коллекции.
    Object? obj2json(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToJson(
          _isDropped(value) ? '<dropped>' : value,
          config: itemConfig,
        ),
      );
    }

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
      _valueKey:
          values.indexed.map((item) => obj2json(item.$1, item.$2)).toList(),
      if (trimmed ?? false) _trimKey: true,
      if (config.units case final units?) _unitsKey: units,
    };
  }

  /// Санитайз значения записи по ключу; при [Sanitize.drop] возвращает
  /// `null`, чтобы [_mapToString] пропустил запись целиком.
  ///
  /// Ключ рендерится РОВНО один раз: полученный текст идёт и в вывод, и
  /// в сегмент пути с именем для правила. Раньше он рисовался дважды —
  /// черновым `entry.key.toString()` ради имени и ещё раз в вывод, — и
  /// свойства [Loggable]-ключа предлагались правилу по двум разным
  /// путям, причём в вывод шёл ВТОРОЙ рендер, а правило по пути
  /// маскировало первый. Черновик к тому же считался безусловно, до
  /// раннего выхода [_sanitizeChild]: без правила ключ рендерился
  /// дважды, а `toString()` звался там, где до 0.6.0 не звался вовсе.
  static String? _mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final depthTheme = theme.depthTheme(depth);

    final String key;
    final String? name;
    if (entry.key case final String stringKey) {
      key = theme.formatValue(stringKey);
      name = stringKey;
    } else {
      final objectKey = entry.key;
      // Сам ключ правилу не предлагается (см. dartdoc [sanitizer]), но
      // его содержимое проходит через обходчики: рендерим под
      // заглушкой, иначе при пустом стеке сегментов ключ ушёл бы в
      // обходчик КОРНЕМ — и был бы предложен. Заглушка не входит ни в
      // путь, ни в глубину, поэтому свойства ключа видны правилу под
      // путём самой записи.
      key = _withSegment(
        _rootGuardSegment,
        () => objectToString(
          objectKey,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
      // Имя и сегмент — данные для правила, а не вывод: стили темы из
      // них убираем. Без правила они не нужны и не считаются.
      name =
          _sanitizing && objectKey != null ? key.ansiRemoveEscapeCodes() : null;
    }

    // Ключ уже отрисован целиком, даже если запись сейчас отбросят: имя
    // для правила — это и есть напечатанный ключ, а решение о drop
    // принимается по имени. Порядок неизбежен, не оптимизация «потом».
    final segment = name ?? 'null';
    final value = _sanitizeChild(segment, name, entry.value);
    if (_isDropped(value)) return null;

    final valueStr = _withSegment(
      segment,
      () => objectToString(
        value,
        depth: depth + 1,
        theme: theme,
        config: config,
      ),
    );

    return '${theme.data.keyStyle(key)}${depthTheme.punctuation(':')}'
        ' ${theme.data.valueStyle(valueStr)}';
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
        .whereType<String>()
        .join(depthTheme.punctuation(', '));

    return '${depthTheme.brackets(start)}$body${depthTheme.brackets(end)}';
  }

  static Map<String, Object?> _mapToJson(
    Map<Object?, Object?> map, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Не передаём units дочерним элементам.
    late final itemConfig = config.copyWith(units: null);

    // Собираем циклом (а не map.map), чтобы уметь пропускать записи,
    // санитизированные до Sanitize.drop.
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      // Ключ рендерится один раз (см. [_mapEntryToString]): его текст —
      // и ключ в JSON, и сегмент пути с именем для правила.
      final String? name;
      if (entry.key case final String stringKey) {
        name = stringKey;
      } else if (entry.key case final objectKey?) {
        // `toString` ключа может зайти в обходчики ([Loggable],
        // [LoggableWrapper]): под заглушкой ключ не будет предложен
        // правилу как корень.
        name = _withSegment(_rootGuardSegment, objectKey.toString);
      } else {
        name = null;
      }

      final segment = name ?? 'null';
      final value = _sanitizeChild(segment, name, entry.value);
      if (_isDropped(value)) continue;

      result[_escapeServiceKey(segment)] = _withSegment(
        segment,
        () => objectToJson(value, config: itemConfig),
      );
    }

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
