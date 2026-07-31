part of 'loggable.dart';

/// Обрабатывает одно выводимое значение внутри `data`.
///
/// Возврат значения, идентичного [SanitizeContext.value], означает «не
/// трогал». Любое другое значение выводится вместо исходного, и внутрь
/// него обход не идёт. Возврат [Sanitize.drop] убирает значение из
/// вывода (см. [Loggable.sanitizer]).
///
/// Правило обязано быть тотальным: исключение из него выходит в
/// publisher (см. спеку, раздел «Ошибки»).
typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);

final class _SanitizeDrop {
  const _SanitizeDrop._();

  @override
  String toString() => '<dropped>';
}

/// Маркеры для [LogValueSanitizer].
abstract final class Sanitize {
  /// Убирает значение из вывода.
  ///
  /// Свойство, запись [Map] или запись `LoggableMultiData` не выводятся
  /// вовсе; в корне вывод пустой. В позиции элемента коллекции
  /// работает как замена на `'<dropped>'`: длина коллекции печатается и
  /// должна остаться честной.
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

  /// Значение, которое реально попадёт в вывод (для свойства с `view` —
  /// сам `view`).
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
      // Плейсхолдер повторного рендера замены корня — не часть пути.
      if (identical(segment, Loggable._rootReplacementPlaceholder)) continue;
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
