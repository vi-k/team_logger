part of 'loggable.dart';

/// Handles one value on its way into the output of `data`.
///
/// Returning a value identical to [SanitizeContext.value] means "left
/// alone". Anything else is substituted for the original: **the original
/// is not walked into**, and its children are never offered to the rule.
/// The replacement, however, renders as an ordinary value — its own
/// children are offered to the rule like any others. Returning
/// [Sanitize.drop] removes the value from the output (see
/// [Loggable.sanitizer]).
///
/// It follows that a rule returning a container that holds a value which
/// matches the same rule again will recurse forever:
///
/// ```dart
/// // Do not do this: the replacement contains 'secret', the rule fires on
/// // it again, and it substitutes the container endlessly.
/// Loggable.sanitizer = (ctx) =>
///     ctx.value == 'secret' ? {'was': 'secret'} : ctx.value;
/// ```
///
/// The rule must be total: an exception from it escapes into the publisher
/// (see the spec, "Errors").
typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);

final class _SanitizeDrop {
  const _SanitizeDrop._();

  @override
  String toString() => '<dropped>';
}

/// Type of the guard segment for the root position; see
/// [Loggable._rootGuardSegment].
final class _SanitizeGuardSegment {
  const _SanitizeGuardSegment();

  @override
  String toString() => '<sanitize-guard>';
}

/// Markers for [LogValueSanitizer].
abstract final class Sanitize {
  /// Removes the value from the output.
  ///
  /// A property, a [Map] entry or a `LoggableMultiData` section is not
  /// printed at all; at the root the output is empty. In a collection
  /// element position it works as a replacement with `'<dropped>'`: the
  /// collection's length is printed and has to stay honest.
  ///
  /// A property is removed by whoever renders it — its `LoggableData`
  /// container. A `Prop` taken on its own has no container (the
  /// `LoggableData.props` list is public, and `p.toLogString()` /
  /// `p.toMapEntry()` can be called one by one), so it prints the same
  /// `'<dropped>'` marker a collection element does: a position that
  /// structurally cannot remove itself would leave the caller with a
  /// dangling separator.
  static const Object drop = _SanitizeDrop._();
}

/// A value's position in the output.
///
/// The context is valid only for the duration of the sanitizer call:
/// [path] is built from the current state of the walk.
final class SanitizeContext {
  /// A property name, a [Map] key or a `LoggableMultiData` section name;
  /// `null` for collection elements and for the root value.
  final String? name;

  /// The value that will actually reach the output.
  ///
  /// For a property with a `view` this is the `view` object itself, NOT the
  /// text it draws: [LoggableView] implementations build their output with
  /// a converter of their own, and such a `view` object never reaches
  /// [Loggable.objectToString]/[Loggable.objectToJson] (see the spec, "The
  /// view rule"). A bare [Loggable] or [LoggableWrapper] used as a `view`
  /// does enter the walkers — but it is still offered to the rule exactly
  /// once, here, and its contents come under this property's path. Where
  /// the converter calls the walkers itself, it calls them for its own
  /// inner values.
  ///
  /// The blind spot to know about: a rule matching on content
  ///
  /// ```dart
  /// (ctx) => '\$data'.contains('4111') ? '***' : ctx.value
  /// ```
  ///
  /// will not fire for `prop('card', pan, view: LoggableView.convert(...))`
  /// — it sees the view object, while what gets printed is the converter's
  /// result. The position is still offered to the rule exactly once, so
  /// rules on [name] and [path] do work: redact such properties by name or
  /// by path.
  ///
  /// [LoggableWrapper], by contrast, is transparent: the rule is offered
  /// the wrapped value, not the wrapper.
  final Object? value;

  /// Depth: 0 is the root value.
  final int depth;

  final List<Object> _segments;

  const SanitizeContext._(this.name, this.value, this.depth, this._segments);

  /// The path from the root: `user.card.number`, `items[0].pan`.
  ///
  /// Built lazily: a rule that looks only at [name] does not pay for
  /// assembling the string.
  String get path {
    final buf = StringBuffer();
    for (final segment in _segments) {
      // The root position's guard segment is not part of the path.
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
