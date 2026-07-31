part of 'loggable.dart';

/// Обрабатывает одно выводимое значение внутри `data`.
///
/// Возврат значения, идентичного [SanitizeContext.value], означает «не
/// трогал». Любое другое значение подставляется вместо исходного:
/// **внутрь оригинала обход не идёт**, его дети правилу не предлагаются
/// вовсе. Но сама замена рендерится как обычное значение — то есть её
/// собственные дети предлагаются правилу наравне с любыми другими.
/// Возврат [Sanitize.drop] убирает значение из вывода (см.
/// [Loggable.sanitizer]).
///
/// Отсюда следует, что правило, возвращающее контейнер, внутри которого
/// лежит значение, снова подходящее под то же правило, зациклится:
///
/// ```dart
/// // Так нельзя: замена содержит 'secret', правило сработает на неё
/// // снова и будет подставлять контейнер бесконечно.
/// Loggable.sanitizer = (ctx) =>
///     ctx.value == 'secret' ? {'was': 'secret'} : ctx.value;
/// ```
///
/// Правило обязано быть тотальным: исключение из него выходит в
/// publisher (см. спеку, раздел «Ошибки»).
typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);

final class _SanitizeDrop {
  const _SanitizeDrop._();

  @override
  String toString() => '<dropped>';
}

/// Тип сегмента-заглушки корневой позиции; см.
/// [Loggable._rootGuardSegment].
final class _SanitizeGuardSegment {
  const _SanitizeGuardSegment();

  @override
  String toString() => '<sanitize-guard>';
}

/// Маркеры для [LogValueSanitizer].
abstract final class Sanitize {
  /// Убирает значение из вывода.
  ///
  /// Свойство, запись [Map] или запись `LoggableMultiData` не выводятся
  /// вовсе; в корне вывод пустой. В позиции элемента коллекции
  /// работает как замена на `'<dropped>'`: длина коллекции печатается и
  /// должна остаться честной.
  ///
  /// Свойство убирается, когда рендерит его контейнер — `LoggableData`.
  /// У отдельно взятого `Prop` (список `LoggableData.props` публичен, и
  /// `p.toLogString()`/`p.toMapEntry()` можно звать поштучно) контейнера
  /// нет: он печатает тот же маркер `'<dropped>'`, что и элемент
  /// коллекции, — позиция, которая структурно не может удалить сама
  /// себя, оставила бы вызывающему висящий разделитель.
  static const Object drop = _SanitizeDrop._();
}

/// Позиция значения при выводе.
///
/// Контекст действителен только во время вызова санитайзера: [path]
/// собирается по текущему состоянию обхода.
final class SanitizeContext {
  /// Имя свойства, ключ [Map] или записи `LoggableMultiData`; `null`
  /// для элементов коллекций и для корневого значения.
  final String? name;

  /// Значение, которое реально попадёт в вывод.
  ///
  /// Для свойства с `view` это сам объект `view`, а НЕ текст, который он
  /// нарисует: реализации [LoggableView] формируют вывод собственным
  /// конвертером, и такой объект `view` в
  /// [Loggable.objectToString]/[Loggable.objectToJson] не уходит (см.
  /// спеку, раздел «Правило view»). Сырой [Loggable] или
  /// [LoggableWrapper] в роли `view`, наоборот, в обходчики заходит —
  /// но правилу он всё равно предлагается ровно один раз, здесь, а его
  /// содержимое — под путём этого свойства. Если конвертер зовёт
  /// обходчики сам — зовёт он их тоже уже для своих внутренних
  /// значений. Слепое пятно, о котором надо знать: правило по
  /// содержимому
  ///
  /// ```dart
  /// (ctx) => '$data'.contains('4111') ? '***' : ctx.value
  /// ```
  ///
  /// для `prop('card', pan, view: LoggableView.convert(...))` не
  /// сработает — оно увидит объект view, а напечатан будет результат
  /// конвертера. Позиция при этом предлагается правилу ровно один раз,
  /// поэтому правила по [name] и [path] работают: такие свойства
  /// редактируйте по имени или пути.
  ///
  /// [LoggableWrapper], наоборот, прозрачен: правилу предлагается
  /// завёрнутое значение, а не обёртка.
  final Object? value;

  /// Глубина: 0 — корневое значение.
  final int depth;

  final List<Object> _segments;

  const SanitizeContext._(this.name, this.value, this.depth, this._segments);

  /// Путь от корня: `user.card.number`, `items[0].pan`.
  ///
  /// Собирается лениво: правило, смотрящее только на [name], не платит
  /// за сборку строки.
  String get path {
    final buf = StringBuffer();
    for (final segment in _segments) {
      // Заглушка корневой позиции — не часть пути.
      if (identical(segment, Loggable._rootGuardSegment)) continue;
      if (segment is int) {
        buf.write('[$segment]');
      } else {
        if (buf.isNotEmpty) buf.write('.');
        buf.write(segment);
      }
    }

    return buf.toString();
  }

  @override
  String toString() => 'SanitizeContext($path)';
}
