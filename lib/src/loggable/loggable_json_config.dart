import 'package:meta/meta.dart';

import 'loggable.dart';
import 'loggable_config.dart';

/// Configuration for [objectToJson].
///
/// [collectionMaxCount] - the maximum number of elements in a collection
/// (for [List], [Set], [Map] and [Iterable]). No limit when null.
///
/// [iterableEfficientLength] - the same assertion as in `LoggableConfig`:
/// a bare [Iterable] has a cheap length and last element, so it can be
/// printed with `":l"` instead of `":trim"`.
///
/// Note that every setting applies recursively, to the object itself and
/// to everything nested inside it, and that a setting once given cannot be
/// reset to null.
abstract base class LoggableJsonConfig with Loggable {
  final int? collectionMaxCount;
  final String? units;
  final bool? iterableEfficientLength;

  const factory LoggableJsonConfig({
    int? collectionMaxCount,
    String? units,
    bool? iterableEfficientLength,
  }) = _LoggableJsonConfig;

  const LoggableJsonConfig._({
    this.collectionMaxCount,
    this.units,
    this.iterableEfficientLength,
  });

  LoggableJsonConfig copyWith({
    int? collectionMaxCount,
    String? units,
    bool? iterableEfficientLength,
  });

  /// The values with the `default ← this config ← force` chain applied.
  ///
  /// The layers are shared with the string output: an application has one
  /// policy, and a second pair of statics for JSON would be a licence for
  /// the two to drift apart. The fields that exist here are taken from
  /// `LoggableConfig`.
  @internal
  int? get resolvedCollectionMaxCount =>
      Loggable.forceConfig.collectionMaxCount ??
      collectionMaxCount ??
      Loggable.defaultConfig.collectionMaxCount;

  @internal
  String? get resolvedUnits =>
      Loggable.forceConfig.units ?? units ?? Loggable.defaultConfig.units;

  @internal
  bool get resolvedIterableEfficientLength =>
      Loggable.forceConfig.iterableEfficientLength ??
      iterableEfficientLength ??
      Loggable.defaultConfig.iterableEfficientLength ??
      LoggableConfig.defaultIterableEfficientLength;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = '$LoggableJsonConfig'
      ..whenNotNull('collectionMaxCount', collectionMaxCount)
      ..whenNotNull('units', units)
      ..whenNotNull('iterableEfficientLength', iterableEfficientLength);
  }
}

/// The "argument not passed" marker for [_LoggableJsonConfig.copyWith].
///
/// A private type of its own rather than `const Object()`: every
/// `const Object()` in a program is the same object. Here the marker is
/// only ever compared against the package's own default arguments, so a
/// collision is not reachable today — but exactly that collision was a
/// real bug elsewhere (see [Prop._notSanitized]), so the same private type
/// is used here too, not only where it is already exploitable.
final class _Undefined {
  const _Undefined();
}

final class _LoggableJsonConfig extends LoggableJsonConfig {
  static const _undefined = _Undefined();

  const _LoggableJsonConfig({
    super.collectionMaxCount,
    super.units,
    super.iterableEfficientLength,
  }) : super._();

  @override
  LoggableJsonConfig copyWith({
    Object? collectionMaxCount = _undefined,
    Object? units = _undefined,
    Object? iterableEfficientLength = _undefined,
  }) =>
      _LoggableJsonConfig(
        collectionMaxCount: identical(collectionMaxCount, _undefined)
            ? this.collectionMaxCount
            : collectionMaxCount as int?,
        units: identical(units, _undefined) ? this.units : units as String?,
        iterableEfficientLength: identical(iterableEfficientLength, _undefined)
            ? this.iterableEfficientLength
            : iterableEfficientLength as bool?,
      );
}
