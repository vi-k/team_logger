import 'dart:math' as math;

extension StringWrapExtension on String {
  List<String> wrap(int? maxWidth) {
    assert(maxWidth == null || maxWidth >= 1);

    if (maxWidth == null) {
      return List.filled(1, this);
    }

    final len = length;

    return List.generate(
      (len / maxWidth).ceil(),
      (index) =>
          substring(index * maxWidth, math.min((index + 1) * maxWidth, len)),
      growable: false,
    );
  }
}
