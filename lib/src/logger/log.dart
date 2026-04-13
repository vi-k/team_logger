import 'package:clock/clock.dart';
import 'package:logger_builder/logger_builder.dart';

final class Log extends CustomLog {
  static int _lastSequenceNum = 0;

  final DateTime time;
  final int sequenceNum;
  final String path;
  final String message;
  final Object? data;
  final Set<String> tags;

  Log(
    super.levelLogger, {
    required this.path,
    required this.message,
    required this.data,
    required this.tags,
    super.error,
    super.stackTrace,
    super.zone,
  })  : sequenceNum = ++_lastSequenceNum,
        time = clock.now();
}

final class LazyTags extends TypedLazy<Set<String>> {
  LazyTags(super.unresolved);

  LazyTags.resolved(super.resolved) : super.resolved();

  @override
  Set<String> convert(Object? resolved) => switch (resolved) {
        null => const {},
        String() => {resolved},
        Iterable<String>() => resolved.toSet(),
        _ => throw Exception('Invalid tags: $resolved'),
      };
}
