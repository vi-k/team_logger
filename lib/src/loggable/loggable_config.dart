import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable.dart';
import 'loggable_json_config.dart';

/// Configuration for [objectToString].
///
/// [enumDotShorthand] - the shorthand `.value` form for enums. When null,
/// the chain layers decide (see below); `true` by default.
///
/// [collectionMaxCount] - the maximum number of elements in a collection
/// (for [List], [Set], [Map] and [Iterable]). No limit when null. For a
/// [Map] the limit counts the entries that survive the rule: a dropped
/// entry does not use up a slot.
///
/// [collectionMaxStringLength] - the maximum length of the string a
/// collection renders to. The result may be longer in practice, because an
/// iterable always keeps its first element and a list keeps its first and
/// last unabridged. No limit when null.
///
/// [collectionShowCount] - whether to show a collection's length as `₌₄`
/// (for [List], [Set] and [Map]). When null, the chain layers decide;
/// `true` by default. For a [Map] this is the length of the original
/// collection — entries the rule dropped are not visible in the output, and
/// the count is the only trace they leave.
///
/// [collectionShowIndexes] - whether to show element indexes as `₀:`, `₁:`
/// and so on. When null, the chain layers decide; `true` by default.
///
/// [iterableEfficientLength] - the caller's assertion that a bare
/// [Iterable] has a cheap length and last element. Without it a collection
/// that is neither a [List] nor a [Set] is walked exactly once: the leading
/// elements and an ellipsis are printed and the length is not read at all,
/// or a single-pass or expensive iterator would suffer. With it the output
/// gets as rich as a [List]'s: the count (`₌₅`) and the last element. Off
/// by default; must not be turned on for a generator.
///
/// [escapeAnsiCodes] - safe output: a control sequence in the text is shown
/// (`[CSI 2 ED]forged`) rather than sent to the terminal. On by default.
/// Turn it off where a value is styled deliberately; for untrusted input do
/// the opposite and turn it on through [Loggable.forceConfig], so that a
/// call site cannot lift it.
///
/// [units] - the unit of measurement, appended to the object's
/// representation as a suffix. No units are added when null.
///
/// [intFormat] and [doubleFormat] - patterns for numbers. The package does
/// not parse them: the pattern goes to the theme's
/// [LogMainTheme.numberFormatter] together with the value, and the
/// formatter is what gives it meaning. A theme without one ignores the
/// pattern and prints the number as it is - no exception is thrown. The
/// recipe over `package:format`:
/// `numberFormatter: (theme, value, pattern) => format(pattern, value)`,
/// and then the config carries `'{:,d}'`, `'{:.4f}'` and so on.
///
/// Note that every setting applies recursively, to the object itself and
/// to everything nested inside it, and that a setting once given cannot be
/// reset to null.
///
/// ## Layers
///
/// An unset (`null`) field is resolved through a chain, weakest first:
///
/// 1. the package default — what is printed when nobody said anything;
/// 2. [Loggable.defaultConfig] — the application's default;
/// 3. this config: from the call site and from the containers on the way to
///    the value (the one closest to the value wins);
/// 4. [Loggable.forceConfig] — the application's policy, which neither a
///    call site nor a nested container can lift.
///
/// Layers 1 and 2 did not exist before, and the defaults of four boolean
/// settings came from the theme. The theme answers for how the output
/// looks; the config for what is printed in it.
///
/// ```dart
/// log.d(
///   'data',
///   data: Loggable.from(
///     [1, 2, [3, 4, 5]],
///     config: LoggableConfig(
///       units: 'kg',
///       collectionMaxCount: 2,
///     ),
///   ),
/// );
/// // data: [₌₃ ₀:1kg, …, ₂:[₌₃ ₀:3kg, …, ₂:5kg]]
/// ```
final class LoggableConfig with Loggable {
  final bool? enumDotShorthand;
  final int? collectionMaxCount;
  final int? collectionMaxStringLength;
  final bool? collectionShowCount;
  final bool? collectionShowIndexes;
  final String? units;
  final String? doubleFormat;
  final String? intFormat;
  final bool? stringInQuotes;
  final bool? escapeAnsiCodes;
  final bool? iterableEfficientLength;

  const LoggableConfig({
    this.enumDotShorthand,
    this.collectionMaxCount,
    this.collectionMaxStringLength,
    this.collectionShowCount,
    this.collectionShowIndexes,
    this.units,
    this.doubleFormat,
    this.intFormat,
    this.stringInQuotes,
    this.escapeAnsiCodes,
    this.iterableEfficientLength,
  });

  /// The package defaults — the floor of the chain, below
  /// [Loggable.defaultConfig].
  ///
  /// The theme used to hold them (`LogMainTheme.stringInQuotes` and its
  /// neighbours), and resolving "the config, else the theme" was spread
  /// across five places in the renderer. The theme now answers for how the
  /// output looks, and the config for what is printed in it.
  static const bool defaultEnumDotShorthand = true;
  static const bool defaultCollectionShowCount = true;
  static const bool defaultCollectionShowIndexes = true;
  static const bool defaultStringInQuotes = true;

  /// Safe output is on by default: untrusted text ends up in logs not out
  /// of malice, but because that is what logs are.
  static const bool defaultEscapeAnsiCodes = true;

  /// A bare [Iterable] is walked once by default: it may be single-pass or
  /// expensive, and the package is not entitled to read its length.
  static const bool defaultIterableEfficientLength = false;

  /// The value of [escapeAnsiCodes] where there is no local config at all.
  ///
  /// The log message, the error text and `units` have no config: the
  /// call-site `config:` wraps `data` only. For them the chain consists of
  /// the application layers, and that is the right set — the message is
  /// exactly the place that wants a policy rather than the caller's
  /// taste.
  @internal
  static bool get appEscapeAnsiCodes =>
      const LoggableConfig().resolvedEscapeAnsiCodes;

  /// The values with the `default ← this config ← force` chain applied.
  ///
  /// They are asked at the point of use rather than folded in beforehand: a
  /// container's config is merged in during the walk, and a layer folded in
  /// before that would be overridden by a nested container. Here there is
  /// nothing to override — the order is written into the expression.
  @internal
  bool get resolvedEnumDotShorthand =>
      Loggable.forceConfig.enumDotShorthand ??
      enumDotShorthand ??
      Loggable.defaultConfig.enumDotShorthand ??
      defaultEnumDotShorthand;

  @internal
  bool get resolvedCollectionShowCount =>
      Loggable.forceConfig.collectionShowCount ??
      collectionShowCount ??
      Loggable.defaultConfig.collectionShowCount ??
      defaultCollectionShowCount;

  @internal
  bool get resolvedCollectionShowIndexes =>
      Loggable.forceConfig.collectionShowIndexes ??
      collectionShowIndexes ??
      Loggable.defaultConfig.collectionShowIndexes ??
      defaultCollectionShowIndexes;

  @internal
  bool get resolvedStringInQuotes =>
      Loggable.forceConfig.stringInQuotes ??
      stringInQuotes ??
      Loggable.defaultConfig.stringInQuotes ??
      defaultStringInQuotes;

  @internal
  bool get resolvedIterableEfficientLength =>
      Loggable.forceConfig.iterableEfficientLength ??
      iterableEfficientLength ??
      Loggable.defaultConfig.iterableEfficientLength ??
      defaultIterableEfficientLength;

  @internal
  bool get resolvedEscapeAnsiCodes =>
      Loggable.forceConfig.escapeAnsiCodes ??
      escapeAnsiCodes ??
      Loggable.defaultConfig.escapeAnsiCodes ??
      defaultEscapeAnsiCodes;

  @internal
  int? get resolvedCollectionMaxCount =>
      Loggable.forceConfig.collectionMaxCount ??
      collectionMaxCount ??
      Loggable.defaultConfig.collectionMaxCount;

  @internal
  int? get resolvedCollectionMaxStringLength =>
      Loggable.forceConfig.collectionMaxStringLength ??
      collectionMaxStringLength ??
      Loggable.defaultConfig.collectionMaxStringLength;

  /// `units` resolve through the chain, but are removed by
  /// `withoutUnits()` on the path of a root sanitizer replacement — there
  /// `units` are already struck out of the config itself, and force does
  /// not bring them back.
  @internal
  String? get resolvedUnits =>
      Loggable.forceConfig.units ?? units ?? Loggable.defaultConfig.units;

  @internal
  String? get resolvedIntFormat =>
      Loggable.forceConfig.intFormat ??
      intFormat ??
      Loggable.defaultConfig.intFormat;

  @internal
  String? get resolvedDoubleFormat =>
      Loggable.forceConfig.doubleFormat ??
      doubleFormat ??
      Loggable.defaultConfig.doubleFormat;

  LoggableConfig merge(LoggableConfig other) => LoggableConfig(
        enumDotShorthand: enumDotShorthand ?? other.enumDotShorthand,
        collectionMaxCount: collectionMaxCount ?? other.collectionMaxCount,
        collectionMaxStringLength:
            collectionMaxStringLength ?? other.collectionMaxStringLength,
        collectionShowCount: collectionShowCount ?? other.collectionShowCount,
        collectionShowIndexes:
            collectionShowIndexes ?? other.collectionShowIndexes,
        units: units ?? other.units,
        doubleFormat: doubleFormat ?? other.doubleFormat,
        intFormat: intFormat ?? other.intFormat,
        stringInQuotes: stringInQuotes ?? other.stringInQuotes,
        escapeAnsiCodes: escapeAnsiCodes ?? other.escapeAnsiCodes,
        iterableEfficientLength:
            iterableEfficientLength ?? other.iterableEfficientLength,
      );

  /// A copy of the configuration without [units].
  ///
  /// Needed where the sanitizer substituted the value: units describe the
  /// original quantity, and a masked value is no longer that quantity (see
  /// `Prop.toLogString`).
  @internal
  LoggableConfig withoutUnits() => LoggableConfig(
        enumDotShorthand: enumDotShorthand,
        collectionMaxCount: collectionMaxCount,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowCount: collectionShowCount,
        collectionShowIndexes: collectionShowIndexes,
        doubleFormat: doubleFormat,
        intFormat: intFormat,
        stringInQuotes: stringInQuotes,
        escapeAnsiCodes: escapeAnsiCodes,
        iterableEfficientLength: iterableEfficientLength,
      );

  /// The config with every layer of the chain resolved to the end.
  LoggableEffectiveConfig toEffectiveConfig() => LoggableEffectiveConfig(
        enumDotShorthand: resolvedEnumDotShorthand,
        collectionMaxCount: resolvedCollectionMaxCount,
        collectionMaxStringLength: resolvedCollectionMaxStringLength,
        collectionShowCount: resolvedCollectionShowCount,
        collectionShowIndexes: resolvedCollectionShowIndexes,
        units: resolvedUnits,
        doubleFormat: resolvedDoubleFormat,
        intFormat: resolvedIntFormat,
        stringInQuotes: resolvedStringInQuotes,
        escapeAnsiCodes: resolvedEscapeAnsiCodes,
        iterableEfficientLength: resolvedIterableEfficientLength,
      );

  LoggableJsonConfig mergeWithJsonConfig(LoggableJsonConfig config) =>
      LoggableJsonConfig(
        collectionMaxCount: collectionMaxCount ?? config.collectionMaxCount,
        units: units ?? config.units,
        iterableEfficientLength:
            iterableEfficientLength ?? config.iterableEfficientLength,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('collectionMaxCount', collectionMaxCount)
      ..prop('collectionMaxStringLength', collectionMaxStringLength)
      ..prop('collectionShowCount', collectionShowCount)
      ..prop('collectionShowIndexes', collectionShowIndexes)
      ..prop('units', units)
      ..prop('doubleFormat', doubleFormat)
      ..prop('intFormat', intFormat)
      ..prop('stringInQuotes', stringInQuotes)
      ..prop('escapeAnsiCodes', escapeAnsiCodes)
      ..prop('iterableEfficientLength', iterableEfficientLength);
  }
}

final class LoggableEffectiveConfig extends LoggableConfig with Loggable {
  const LoggableEffectiveConfig({
    required bool super.enumDotShorthand,
    required super.collectionMaxCount,
    required super.collectionMaxStringLength,
    required bool super.collectionShowCount,
    required bool super.collectionShowIndexes,
    required super.units,
    required super.doubleFormat,
    required super.intFormat,
    required bool super.stringInQuotes,
    required bool super.escapeAnsiCodes,
    required bool super.iterableEfficientLength,
  });

  @override
  bool get enumDotShorthand => super.enumDotShorthand!;

  @override
  bool get collectionShowCount => super.collectionShowCount!;

  @override
  bool get collectionShowIndexes => super.collectionShowIndexes!;

  @override
  bool get stringInQuotes => super.stringInQuotes!;

  @override
  bool get escapeAnsiCodes => super.escapeAnsiCodes!;

  @override
  bool get iterableEfficientLength => super.iterableEfficientLength!;
}
