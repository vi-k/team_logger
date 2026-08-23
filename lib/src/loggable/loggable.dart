import 'dart:math' as math;

import 'package:ansi_escape_codes/extensions.dart';
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

  /// The global sanitizer for values on their way into the output.
  ///
  /// `null` (the default) means output with no processing and no overhead.
  /// It applies in [objectToString] and [objectToJson], and therefore to
  /// ALL outputs: publishers, an in-app log viewer, session export.
  ///
  /// Every value is processed exactly once, by whoever knows its position
  /// (a property, a [Map] key, an element index). The rule is given a
  /// [SanitizeContext] and returns the original value, a replacement, or
  /// [Sanitize.drop].
  ///
  /// ```dart
  /// Loggable.sanitizer = (ctx) => switch (ctx.name) {
  ///   'password' || 'token' => Sanitize.drop,
  ///   _ => ctx.value,
  /// };
  /// ```
  ///
  /// The rule has to be a pure function of [SanitizeContext]: no side
  /// effects (being called does not guarantee the value will be printed —
  /// see the spec, "Cycles, limits, laziness") and no rendering. Rendering
  /// is not only an explicit [objectToString]/[objectToJson], but also
  /// interpolating `'${ctx.value}'` or calling `ctx.value.toString()` for
  /// [Loggable], [LoggableData], [LoggableWrapper] and [LoggableMultiData]:
  /// their `toString` enters the very walkers the rule was called from.
  /// Logging from inside the rule is out too.
  ///
  /// A [Map] key is not offered to the rule: the rule gets the entry's
  /// value and sees the key as [SanitizeContext.name] and as part of
  /// [SanitizeContext.path]. A secret in the key itself
  /// (`{'ann@example.com': {...}}`) cannot be cleaned out by replacement —
  /// a name-based rule can only drop the whole entry with
  /// [Sanitize.drop].
  ///
  /// Values INSIDE a key object are offered only where rendering the key
  /// enters the walkers: in the string output always, in JSON only for
  /// keys whose `toString()` calls a walker itself ([Loggable],
  /// [LoggableData], [LoggableWrapper], [LoggableMultiData]). Any other key
  /// [objectToJson] draws with a plain `key.toString()`, past the walkers —
  /// so a secret inside an ordinary container key
  /// (`{{'pw': 'hunter2'}: 'primary'}`) is masked on the console
  /// (`{{pw: "<masked>"}: "primary"}`) and survives into [objectToJson]
  /// (`{"{pw: hunter2}": "primary"}`), and therefore into a JSONL file
  /// written with `dataFormat: FileLogDataFormat.json` (the default,
  /// `text`, writes the string — already masked — form). The only way to
  /// get the secret out of there is to drop the whole entry, and by a rule
  /// on the VALUE: the key's text differs between the two outputs (see
  /// below), so a rule on it would fire in one of them only. And where a
  /// key's contents are offered, they come under the CONTAINER's path
  /// rather than the entry's: in `{'acc': {Account('DE89'): 'x'}}` the
  /// key's property arrives as `acc.iban`, while the entry itself is
  /// `acc.Account(iban: "DE89")`.
  ///
  /// For a non-`String` key, [SanitizeContext.name] is the key as THIS
  /// PARTICULAR output draws it: the string one through the walker and the
  /// theme (`[₌₂ ₀:1, ₁:2]`, `.admin`), JSON through `key.toString()`
  /// (`[1, 2]`, `Role.admin`). The forms differ, and the string one depends
  /// on the theme as well, so a rule on the key's text fires in one output
  /// and lets the entry through in the other: redact such entries by value,
  /// or drop them whole.
  ///
  /// The sanitizer is a static field and therefore lives within one
  /// isolate: a rule installed in the main isolate does not apply to logs
  /// rendered in a spawned one — it has to be set again there.
  ///
  /// The ROOT value — the `data` object itself — is offered to the rule
  /// unnamed, at `depth == 0`. The direct user paths offer it too, the ones
  /// that never enter the walkers: [toString] on [Loggable] and
  /// [LoggableData], `LoggableMultiData.toString`, `LogMessage` in the
  /// printer. So a `depth == 0` rule also changes what `'$obj'`/`print(obj)`
  /// prints, and [Sanitize.drop] at the root renders an empty string
  /// there.
  ///
  /// A root replacement renders with the container's settings
  /// (`collectionMaxCount`, `stringInQuotes`, the number formats) but
  /// WITHOUT its `units`: units describe the original quantity, and a mask
  /// is not that quantity. A property replacement behaves exactly the
  /// same.
  ///
  /// The scope is values INSIDE `data` only. `message`, `error`,
  /// `stackTrace`, the tags and the namespace path do not pass through the
  /// [objectToString]/[objectToJson] walkers: the printer prints
  /// `log.message` as it is and `error` through `toString()`,
  /// `FileLogCodec` writes them the same way, and the tags and the logger
  /// name are turned into strings by `LazyTags` and `LazyString` — so the
  /// sanitizer never sees these fields and cannot substitute them. The root
  /// offer does not reach them either: the library renders all of it
  /// through [renderOutsideSanitizerScope]. Masking these fields, or
  /// dropping the log entirely, is the job of
  /// `Logger.transformer`.
  ///
  /// THE BOUNDARY: only a `toString()` the library itself calls is
  /// suppressed. Interpolation the caller did — `log.i('$obj')` or
  /// `log.i(() => '$obj')` — is still seen by the rule: it runs in user
  /// code and reaches the library as a finished string. That is the one
  /// case where `depth == 0` changes the text of a log.
  ///
  /// The rule must not throw: there is no fail-closed guard here, unlike
  /// in `Logger.transformer`. The exception escapes into whichever
  /// publisher was rendering at the time: `FileLogStorage` hands it to its
  /// `onError` and writes a fallback line without the data, while
  /// `ConsoleLogPrinter` does not catch it — the exception leaves
  /// `publish()`, and `MultiPublisher` isolates it, but a printer on its
  /// own propagates it to the logging call site.
  static LogValueSanitizer? sanitizer;

  /// The application's default: how to render what the call site left
  /// unsaid.
  ///
  /// The weakest layer of the `defaultConfig ← call site ← [forceConfig]`
  /// chain. Any config from a call site and any container's config
  /// override it, so this is where preferences go ("our strings carry no
  /// quotes") rather than policy — policy has [forceConfig].
  ///
  /// A per-isolate static, like [sanitizer]: [objectToString] and
  /// [objectToJson] are called without a theme and without a logger too,
  /// and the default has to apply there as well. Set it again in a spawned
  /// isolate.
  static LoggableConfig defaultConfig = const LoggableConfig();

  /// The application's policy: what a call site cannot lift.
  ///
  /// The strongest layer of the `[defaultConfig] ← call site ← forceConfig`
  /// chain. It overrides both the call's config and a container's — including
  /// one merged in during the walk, deep inside the data. Unset (`null`)
  /// fields are not policy and are decided by the layers below.
  ///
  /// Units do not belong here: `units` describe one particular quantity
  /// rather than a way of printing, and forced ones would be pinned onto
  /// everything. There is no prohibition — the "force overrides everything"
  /// contract matters more than one special guard — but a root sanitizer
  /// replacement strips units even against force: a replacement is not the
  /// original quantity.
  ///
  /// A per-isolate static, like [sanitizer]. Set it again in a spawned
  /// isolate.
  static LoggableConfig forceConfig = const LoggableConfig();

  /// Path segments down to the current value: a [String] is a name or a
  /// key, an [int] is an index. A static stack, like [_visiting], so that
  /// the walkers' signatures do not have to change.
  static final List<Object> _sanitizeSegments = <Object>[];

  static bool get _sanitizing => sanitizer != null;

  /// The guard segment for the root position: it keeps [_sanitizeSegments]
  /// non-empty while staying out of the path and out of the depth count.
  ///
  /// It is pushed twice (see [_sanitizeRoot]): for the duration of the
  /// rule's call on the root — otherwise rendering from inside the rule
  /// would land in the root branch again and recurse — and for re-rendering
  /// the value that replaced the root — otherwise the sanitizer would fire
  /// on the replacement a second time.
  ///
  /// A private type of its own rather than `const Object()`: two different
  /// `const Object()`s are identical, and the marker would be confused with
  /// any other (see [Prop._notSanitized]).
  static const Object _rootGuardSegment = _SanitizeGuardSegment();

  /// How many guards are in [_sanitizeSegments] right now (0 or 1), so
  /// that [_sanitizeChild] and [SanitizeContext.path] can exclude them in
  /// O(1) instead of scanning the stack for every node.
  static int _placeholderCount = 0;

  /// Applies the sanitizer to a child, knowing its position.
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
  /// возвращает готовый строковый вывод вместе с признаком дропа.
  ///
  /// `null` означает «рендерить самому вызывающему»: правило значение не
  /// тронуло, санитайзера нет, либо это вообще не корень — стек
  /// сегментов не пуст, а значит значение уже предложено правилу по
  /// своей позиции.
  ///
  /// `dropped` отдаётся отдельным полем, а не пустым `text`: замена
  /// вправе легитимно отрендериться в пустую строку (`Loggable.builder`
  /// без свойств, пустая [LoggableMultiData]), и по пустоте текста дроп
  /// от неё не отличить — а блок данных в принтере пропадает только у
  /// дропа.
  ///
  /// ЕДИНСТВЕННАЯ точка корневого предложения для строкового вывода. Её
  /// зовёт [objectToString], и её же ОБЯЗАНЫ звать альтернативные
  /// рендереры multi-data (`LoggableMultiData.toString` и `LogMessage` в
  /// принтере): они входят сразу в [forEachMultiDataEntry], поэтому без
  /// этого вызова корень не предлагался бы правилу вовсе — на консоли
  /// печаталось бы то, что в JSONL-файле правило выбрасывает.
  @internal
  static ({String text, bool dropped})? sanitizeRootToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) return null;

    final sanitized = _sanitizeRoot(obj);
    if (identical(sanitized, Sanitize.drop)) return (text: '', dropped: true);
    if (identical(sanitized, obj)) return null;

    // Сегмент-заглушка держит стек непустым: к замене санитайзер
    // повторно не применится. В depth/path он не учитывается.
    return (
      text: _withSegment(
        _rootGuardSegment,
        () => objectToString(
          sanitized,
          theme: theme,
          depth: depth,
          config: _rootConfig(obj, config),
        ),
      ),
      dropped: false,
    );
  }

  /// Конфигурация, которой рендерится ЗАМЕНА корня.
  ///
  /// Замена встаёт на место контейнера, поэтому форматируется его
  /// настройками: у [LoggableMultiData] свой `config`, и обходчик его не
  /// видит — ему передан только окружающий. Без этого мержа рендереры
  /// расходились бы: `LoggableMultiData.toString` и `LogMessage`
  /// передают сюда `data.config` сами (для них мерж идемпотентен), а
  /// [objectToString]/[objectToJson] печатали бы замену без лимитов
  /// контейнера — то есть JSONL расходился бы с консолью.
  ///
  /// `units` при этом снимаются: единицы описывают исходную величину, а
  /// замена ею не является. Ровно то же делает свойство (см.
  /// `Prop.toLogString`), и корень обязан вести себя так же. Остальные
  /// поля конфига описывают не значение, а способ печати
  /// (`collectionMaxCount`, `stringInQuotes`, форматы чисел) — они
  /// наследуются.
  static LoggableConfig _rootConfig(Object? obj, LoggableConfig config) =>
      (_containerConfig(obj)?.merge(config) ?? config).withoutUnits();

  /// То же, что [_rootConfig], но для JSON-вывода.
  static LoggableJsonConfig _rootJsonConfig(
    Object? obj,
    LoggableJsonConfig config,
  ) =>
      (_containerConfig(obj)?.mergeWithJsonConfig(config) ?? config)
          .copyWith(units: null);

  /// Собственный config контейнера, стоящего в корне, или `null`.
  ///
  /// Единая точка для [_rootConfig] и [_rootJsonConfig]: контейнеров с
  /// собственным config несколько, и раньше общий код видел только
  /// [LoggableMultiData]. У билдеров config лежит в приватном поле
  /// подкласса, поэтому спрашиваем его через [LoggableData._ownConfig].
  ///
  /// `LoggableWrapper` сюда не попадает намеренно: он разворачивает себя
  /// до обхода (`toString`/`toJson` зовут `objectToString`/`objectToJson`
  /// на своих данных со своим config), поэтому правилу предлагается уже
  /// содержимое, а не обёртка.
  static LoggableConfig? _containerConfig(Object? obj) => switch (obj) {
        LoggableMultiData() => obj.config,
        LoggableData() => obj._ownConfig,
        _ => null,
      };

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
  ///
  /// Зовут её `LogMessage` в принтере и `FileLogCodec`: у обоих блок
  /// данных при дропе должен исчезать целиком, а не превращаться в
  /// пустую строку.
  @internal
  static ({String text, bool dropped}) renderRoot(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (!_sanitizing) {
      return (
        text: objectToString(obj, theme: theme, config: config),
        dropped: false,
      );
    }

    // Обёртка разворачивается ДО корневого предложения — как в
    // [objectToString]: правилу показывается завёрнутое значение, а не
    // упаковка параметров рендера.
    var value = obj;
    var effective = config;
    while (value is LoggableWrapper) {
      effective = value.config.merge(effective);
      value = value.data;
    }

    if (sanitizeRootToString(value, theme: theme, config: effective)
        case final rendered?) {
      return rendered;
    }

    // Корень уже предложен строкой выше, поэтому рендерится под
    // заглушкой: без неё [objectToString] увидел бы пустой стек и
    // предложил бы то же значение второй раз.
    return (
      text: _withSegment(
        _rootGuardSegment,
        () => objectToString(value, theme: theme, config: effective),
      ),
      dropped: false,
    );
  }

  /// То же, что [renderRoot], но для JSON-вывода.
  ///
  /// [objectToJson] на отброшенном корне отдаёт `null`, а `null` — ещё и
  /// законное значение: по нему одному дроп не опознать. `FileLogCodec`
  /// же обязан в этом случае не писать ключ `data` вовсе — ровно как
  /// принтер убирает блок данных.
  @internal
  static ({Object? json, bool dropped}) renderRootJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) {
      return (json: objectToJson(obj, config: config), dropped: false);
    }

    var value = obj;
    var effective = config;
    while (value is LoggableWrapper) {
      effective = value.config.mergeWithJsonConfig(effective);
      value = value.data;
    }

    final sanitized = _sanitizeRoot(value);
    if (identical(sanitized, Sanitize.drop)) return (json: null, dropped: true);

    // Заглушка держится на весь рендер корня — и замены, и нетронутого
    // значения (см. [objectToJson]).
    return (
      json: _withSegment(
        _rootGuardSegment,
        () => identical(sanitized, value)
            ? _visitToJson(value, config: effective)
            : objectToJson(
                sanitized,
                config: _rootJsonConfig(value, effective),
              ),
      ),
      dropped: false,
    );
  }

  /// Выполняет [render] с ПОДАВЛЕННЫМ корневым предложением: то, что
  /// библиотека печатает внутри, правилу как корень не показывается.
  ///
  /// Нужно там, где библиотека сама зовёт `toString()` у
  /// пользовательского объекта, НЕ входящего в `data`:
  ///
  /// - `error` — в принтере (`LogMessage`) и в `FileLogCodec`;
  /// - `stackTrace` — там же; в принтере через ЛЕНИВЫЙ `Trace.from`,
  ///   поэтому подавление обязано накрывать и чтение фреймов;
  /// - теги — `LazyTags.convert`, вместе с диагностикой невалидного
  ///   значения;
  /// - `message` и имя неймспейса — `_GuardedLazyString.convert`.
  ///
  /// Область действия санитайзера — только значения внутри `data` (см.
  /// [sanitizer]), и корневое предложение, которое делает `toString()`
  /// у [Loggable] и [LoggableData], до этих значений доходить не должно:
  /// правило по `depth == 0` иначе стирало бы ошибку (оставляя висящее
  /// двоеточие) или текст лога, а `Log.tags` и `Logger.path` — переписывало
  /// бы; последние два вообще не рендер: они кэшируются, участвуют в
  /// фильтрах `activeTags`/`activeNamespaces` и именно их видят
  /// publisher'ы, ничего не рисующие.
  ///
  /// Оборачивать надо ТО МЕСТО, где значение реально приводится к строке,
  /// а не то, где создан ленивый холдер: `Trace.from` и `TypedLazy`
  /// стрингуют значение при первом чтении, которое случается позже.
  /// Пользовательское замыкание (ленивое сообщение, ленивое имя) при этом
  /// остаётся СНАРУЖИ подавления — внутри него санитайзер работает как
  /// обычно.
  ///
  /// Позиции вложенных значений не меняются: заглушка не входит ни в
  /// путь, ни в счёт глубины, — свойства такого объекта предлагаются
  /// правилу ровно как и раньше.
  @internal
  static T renderOutsideSanitizerScope<T>(T Function() render) =>
      _withSegment(_rootGuardSegment, render);

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
  ///
  /// Возвращает `true`, если хотя бы одну запись правило отбросило.
  /// Нужно принтеру: multi-data, у которой выброшены ВСЕ секции, не
  /// должна оставлять висящую метку `login: ` без содержимого, а пустая
  /// сама по себе multi-data двоеточие сохраняет. Различать эти два
  /// случая по пустоте текста нельзя — только по факту дропа.
  @internal
  static bool forEachMultiDataEntry(
    LoggableMultiData data,
    void Function(String key, Object? value) render,
  ) {
    var dropped = false;
    for (final entry in data.data.entries) {
      final sanitized = _sanitizeChild(entry.key, entry.key, entry.value);
      if (_isDropped(sanitized)) {
        dropped = true;
        continue;
      }

      _withSegment(entry.key, () => render(entry.key, sanitized));
    }

    return dropped;
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

  /// Класс, подмешавший [Loggable], тем самым принял, что его `toString`
  /// — это рендеринг лога: свойства здесь санитайзятся так же, как в
  /// [objectToString], поэтому и сам объект в корневой позиции
  /// предлагается правилу (см. [_rootToString]).
  @override
  String toString() => _rootToString(this, () => logClassInfo().toLogString());

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
      return rendered.text;
    }

    // Корень, которого правило не тронуло, рендерится под заглушкой —
    // не только замена. Иначе стек на время рендера корня остался бы
    // пустым, и `toString()` любого [Loggable], до которого рендер
    // доберётся напрямую (ключ [Map], интерполяция внутри чужого
    // `toString`), сделал бы СВОЙ корневой офер — тот же корень был бы
    // предложен правилу второй раз.
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      return _withSegment(
        _rootGuardSegment,
        () => _visitToString(obj, theme: theme, depth: depth, config: config),
      );
    }

    return _visitToString(obj, theme: theme, depth: depth, config: config);
  }

  /// Рендер с защитой от циклов; корневое предложение к этому моменту
  /// уже сделано.
  static String _visitToString(
    Object? obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
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

  /// Рендерит значение, стоящее в КОРНЕВОЙ позиции, собственным
  /// `toString` вызывающего, предложив его сначала правилу.
  ///
  /// `toString` — прямой пользовательский путь (интерполяция, `print`,
  /// отладчик), в [objectToString] он не заходит, поэтому корневое
  /// предложение делает сам. Внутри обхода стек сегментов не пуст —
  /// там значение уже предложено своей позицией, и правилу второй раз
  /// не показывается.
  ///
  /// Замена рендерится обходчиком как обычное значение: собственный
  /// `config` вызывающего (у `Loggable.builder`) к ней не применяется —
  /// ровно как в [objectToString], где замена корня-[LoggableData] тоже
  /// его не наследует.
  static String _rootToString(Object? obj, String Function() render) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) return render();

    final sanitized = _sanitizeRoot(obj);
    if (identical(sanitized, Sanitize.drop)) return '';

    return _withSegment(
      _rootGuardSegment,
      () => identical(sanitized, obj) ? render() : objectToString(sanitized),
    );
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
            config: config.toEffectiveConfig(),
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
      // Голый Iterable по умолчанию обходится один раз: длина и последний
      // элемент у него могут быть дорогими или одноразовыми. Знает об этом
      // только вызывающий — он и говорит.
      Iterable<Object?>() => config.resolvedIterableEfficientLength
          ? efficientLengthIterableToString(
              obj,
              theme: theme,
              depth: depth,
              config: config,
            )
          : iterableToString(
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
      _ => theme.formatValue(
          obj.toString(),
          escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
        )
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

  /// Converts [obj] to a JSON-compatible value.
  ///
  /// Map keys are strings as required by JSON. Non-string keys use
  /// `toString()`. If distinct emitted entries produce the same JSON key, an
  /// [ArgumentError] is thrown instead of silently keeping the later value.
  /// Entries removed by [Sanitize.drop] do not participate in this check.
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

      // Сегмент-заглушка держит стек непустым на ВЕСЬ рендер корня — и
      // замены, и нетронутого значения (см. [objectToString]): к корню
      // санитайзер повторно не применится. В depth/path заглушка не
      // учитывается. Конфигурация замены — как в [sanitizeRootToString]
      // (см. [_rootJsonConfig]), иначе JSON разошёлся бы со строковым
      // выводом.
      return _withSegment(
        _rootGuardSegment,
        () => identical(sanitized, obj)
            ? _visitToJson(obj, config: config)
            : objectToJson(sanitized, config: _rootJsonConfig(obj, config)),
      );
    }

    return _visitToJson(obj, config: config);
  }

  /// Рендер с защитой от циклов; корневое предложение к этому моменту
  /// уже сделано.
  static Object? _visitToJson(
    Object? obj, {
    required LoggableJsonConfig config,
  }) {
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
      Iterable<Object?>() => config.resolvedIterableEfficientLength
          ? efficientLengthIterableToJson(obj, config: config)
          : iterableToJson(obj, config: config),
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
  ///
  /// Бросает [ArgumentError], если лимит количества отрицательный, лимит
  /// длины не положительный или разделители содержат управляющие коды.
  @visibleForTesting
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

    final depthTheme = theme.depthTheme(depth);
    final showCount = config.resolvedCollectionShowCount;
    final showIndexes = config.resolvedCollectionShowIndexes;

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
  /// `[a, b, c, d]`.
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

    var maxCount = config.resolvedCollectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    if (maxCount == null || iterable.length <= maxCount) {
      final values =
          iterable.indexed.map((item) => obj2json(item.$1, item.$2)).toList();
      return isList && config.resolvedUnits == null
          ? values
          : {
              _kindKey: type,
              _valueKey: values,
              if (config.resolvedUnits case final units?) _unitsKey: units,
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
      if (config.resolvedUnits case final units?) _unitsKey: units,
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
  ///
  /// Бросает [ArgumentError], если лимит количества отрицательный, лимит
  /// длины не положительный или разделители содержат управляющие коды.
  @visibleForTesting
  static String iterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

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
      showIndexes: config.resolvedCollectionShowIndexes,
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

    var maxCount = config.resolvedCollectionMaxCount;
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
      if (config.resolvedUnits case final units?) _unitsKey: units,
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
      key = theme.formatValue(
        stringKey,
        escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
      );
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
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

    final depthTheme = theme.depthTheme(depth);
    final showCount = config.resolvedCollectionShowCount;

    final buf = StringBuffer(depthTheme.brackets(start));

    // Ни длина, ни последняя запись в этом режиме не нужны.
    if (!showCount && maxCount == null && maxLength == null) {
      var isFirst = true;
      for (final entry in map.entries) {
        final item = _mapEntryToString(
          entry,
          theme: theme,
          depth: depth,
          config: config,
        );
        if (item == null) continue;

        if (!isFirst) buf.write(depthTheme.punctuation(', '));
        buf.write(item);
        isFirst = false;
      }
      buf.write(depthTheme.brackets(end));

      return buf.toString();
    }

    final count = map.length;
    var reservedLength = start.length + end.length;

    if (showCount) {
      final countText = '${theme.formatCount(count)}${count > 0 ? ' ' : ''}';
      reservedLength += countText.length;
      buf.write(depthTheme.description(countText));
    }

    _addMapEntriesToBuf(
      buf,
      map,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      count: count,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  /// Пишет записи `Map` с теми же правилами обрезки, что и у списка:
  /// приоритет у первых записей и последней, вместо изъятого — многоточие.
  ///
  /// Отдельная реализация, а не общая с
  /// [_addEfficientLengthIterableItemsToBuf], из-за санитайзера: у списка
  /// `Sanitize.drop` оставляет маркер `<dropped>` и позиция сохраняется, а у
  /// `Map` запись исчезает совсем. Поэтому лимит здесь считает **выжившие**
  /// записи, а заявленная длина остаётся длиной исходной `Map` — иначе
  /// удалённые правилом записи не оставили бы после себя никакого следа.
  static void _addMapEntriesToBuf(
    StringBuffer buf,
    Map<Object?, Object?> map, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int count,
    required int? maxCount,
    required int? maxLength,
  }) {
    String? entry2str(MapEntry<Object?, Object?> entry) => _mapEntryToString(
          entry,
          theme: theme,
          depth: depth,
          config: config,
        );

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    const delimiterStr = ', ';
    const delimiterSize = delimiterStr.length;
    late final delimiter = depthTheme.punctuation(delimiterStr);

    final ellipsisStr = theme.main.ellipsis;
    final ellipsisSize = ellipsisStr.length;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    late final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    if (count == 0) return;

    // Ни одной записи показать нельзя: {₌ₙ …}
    if (maxCount != null && maxCount <= 0) {
      buf.write(ellipsis);

      return;
    }

    final iterator = map.entries.iterator;

    /// Следующая выжившая запись или `null`, если их больше нет.
    String? nextItem() {
      while (iterator.moveNext()) {
        if (entry2str(iterator.current) case final item?) return item;
      }

      return null;
    }

    final first = nextItem();
    // Всё вычеркнуто правилом: {₌ₙ}
    if (first == null) return;

    final firstSize = first.lengthWithoutEscapeCodes;
    // Первая запись не помещается — показываем только многоточие, но лишь
    // если сама она длиннее многоточия.
    if (!hasSpaceFor(firstSize) && firstSize > ellipsisSize) {
      buf.write(ellipsis);

      return;
    }

    final displayedCount = maxCount == null ? count : math.min(maxCount, count);
    final truncated = displayedCount < count;

    // Хвост рендерится лениво: при displayedCount == 1 его в выводе нет, а
    // рендер — это ещё и санитайз, то есть правилу предлагалась бы запись,
    // отсечённая лимитом по количеству.
    late final last = truncated ? entry2str(map.entries.last) : null;

    if (!truncated) {
      // Показываем всё, что выжило, пока хватает места.
      buf.write(first);
      var usedSize = firstSize;
      for (var item = nextItem(); item != null; item = nextItem()) {
        final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;
        if (!hasSpaceFor(usedSize + itemSize)) {
          if (hasSpaceFor(usedSize + delimiterSize + ellipsisSize)) {
            buf.write(delimiterAndEllipsis);
          }

          return;
        }

        buf
          ..write(delimiter)
          ..write(item);
        usedSize += itemSize;
      }

      return;
    }

    // Место под многоточие и хвост бронируется заранее: они важнее середины.
    var tailSize = delimiterSize + ellipsisSize;
    if (last case final item?) {
      tailSize += delimiterSize + item.lengthWithoutEscapeCodes;
    }

    if (!hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
      buf.write(ellipsis);

      return;
    }

    buf.write(first);

    void writeTail() {
      buf.write(delimiterAndEllipsis);
      if (last case final item?) {
        buf
          ..write(delimiter)
          ..write(item);
      }
    }

    // Одна запись плюс многоточие: {₌ₙ a: 1, …}
    if (displayedCount == 1 || !hasSpaceFor(firstSize + tailSize)) {
      buf.write(delimiterAndEllipsis);

      return;
    }

    var usedSize = firstSize + tailSize;
    // Середина: записи между первой и хвостом, пока хватает места.
    for (var shown = 1; shown < displayedCount - 1; shown++) {
      final item = nextItem();
      if (item == null) break;

      final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;
      if (!hasSpaceFor(usedSize + itemSize)) break;

      buf
        ..write(delimiter)
        ..write(item);
      usedSize += itemSize;
    }

    writeTail();
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

    /// Кладёт запись в [result]; `false` — запись вычеркнута правилом.
    bool addEntry(MapEntry<Object?, Object?> entry) {
      // Ключ рендерится один раз (см. [_mapEntryToString]): его текст —
      // и ключ в JSON, и сегмент пути с именем для правила.
      final String? name;
      if (entry.key case final String stringKey) {
        name = stringKey;
      } else if (entry.key case final objectKey?) {
        // `toString` ключа может зайти в обходчики ([Loggable],
        // [LoggableData], [LoggableWrapper], [LoggableMultiData]): под
        // заглушкой ключ не будет предложен правилу как корень.
        name = _withSegment(_rootGuardSegment, objectKey.toString);
      } else {
        name = null;
      }

      final segment = name ?? 'null';
      final value = _sanitizeChild(segment, name, entry.value);
      if (_isDropped(value)) return false;

      final jsonKey = _escapeServiceKey(segment);
      if (result.containsKey(jsonKey)) {
        throw ArgumentError('Map keys must have unique JSON representations');
      }

      result[jsonKey] = _withSegment(
        segment,
        () => objectToJson(value, config: itemConfig),
      );

      return true;
    }

    final count = map.length;
    final maxCount = config.resolvedCollectionMaxCount;

    // Целая `Map` остаётся обычным JSON-объектом — форму меняет только
    // обрезка, ровно как у списка (см. [listToJson]).
    if (maxCount == null || count <= maxCount) {
      map.entries.forEach(addEntry);

      return switch (config.resolvedUnits) {
        null => result,
        final units => {...result, _unitsKey: units}
      };
    }

    // Приоритет тот же, что в строковом выводе: первые записи и последняя.
    // Лимит считает выжившие записи, а `:l` остаётся длиной исходной `Map`.
    if (maxCount > 0) {
      final iterator = map.entries.iterator;
      var shown = 0;
      while (shown < maxCount - 1 && iterator.moveNext()) {
        if (addEntry(iterator.current)) shown++;
      }

      if (maxCount > 1) addEntry(map.entries.last);
    }

    return {
      _kindKey: 'map',
      _lengthKey: count,
      _valueKey: result,
      if (config.resolvedUnits case final units?) _unitsKey: units,
    };
  }

  static String _enumToString(
    Enum obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dotShorthand = '.${theme.formatValue(
      obj.name,
      escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
    )}';
    return config.resolvedEnumDotShorthand
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
      '${switch (config.resolvedIntFormat) {
        null => obj.toString(),
        final f => theme.formatNumber(obj, f),
      }}'
      '${unitsToString(config.resolvedUnits, theme)}';

  static String _doubleToString(
    double obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (obj.isFinite) {
      return '${switch (config.resolvedDoubleFormat) {
        null => obj.toString(),
        final f => theme.formatNumber(obj, f),
      }}'
          '${unitsToString(config.resolvedUnits, theme)}';
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
      switch (config.resolvedUnits) {
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
      if (config.resolvedUnits case final units?) {
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
    final stringInQuotes = config.resolvedStringInQuotes;
    final escapeAnsiCodes = config.resolvedEscapeAnsiCodes;

    return stringInQuotes
        ? '${theme.styledOpeningQuote}'
            '${theme.formatValue(obj, escapeAnsiCodes: escapeAnsiCodes)}'
            '${theme.styledClosingQuote}'
        : theme.formatValue(obj, escapeAnsiCodes: escapeAnsiCodes);
  }

  static String _dateTimeToString(
    DateTime obj, {
    LogTheme theme = LogTheme.noColors,
  }) =>
      theme.formatValue(
        obj.toIso8601String(),
        // Дата собрана пакетом, недоверенного текста в ней нет; слои
        // приложения всё равно спрашиваем, чтобы политика была одна.
        escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
      );

  static String unitsToString(
    String? units,
    LogTheme theme,
  ) =>
      units == null
          ? ''
          : theme.data.unitsStyle(
              theme.formatValue(
                units,
                // Единицы пишет разработчик в конфиге, не внешний ввод.
                escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
              ),
            );
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
        // Значение интерполирует пакет, поэтому обезвреживает тоже он:
        // собранный текст view уже считается отрендеренным, и там режим
        // выключен (см. `Prop.toLogString`).
        final value => '${theme.formatValue(
            '$value',
            escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
          )}${Loggable.unitsToString(units, theme)}',
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

void _validateIterableToStringArguments({
  required int? maxCount,
  required int? maxLength,
  required String start,
  required String end,
}) {
  if (maxCount != null && maxCount < 0) {
    throw ArgumentError.value(
      maxCount,
      'config.collectionMaxCount',
      'Must not be negative',
    );
  }
  if (maxLength != null && maxLength <= 0) {
    throw ArgumentError.value(
      maxLength,
      'config.collectionMaxStringLength',
      'Must be positive',
    );
  }
  if (_hasControlCode(start)) {
    throw ArgumentError.value(
      start,
      'start',
      'Must not contain ANSI escape or control codes',
    );
  }
  if (_hasControlCode(end)) {
    throw ArgumentError.value(
      end,
      'end',
      'Must not contain ANSI escape or control codes',
    );
  }
}

bool _hasControlCode(String value) {
  for (var i = 0; i < value.length; i++) {
    final codeUnit = value.codeUnitAt(i);
    if (codeUnit <= 0x1F || codeUnit >= 0x7F && codeUnit <= 0x9F) {
      return true;
    }
  }

  return false;
}
