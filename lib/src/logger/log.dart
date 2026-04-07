import 'package:clock/clock.dart';
import 'package:logger_builder/logger_builder.dart';

final class Log extends CustomLog {
  static int _lastSequenceNum = 0;

  final DateTime time;
  final int sequenceNum;
  final LazyString _lazyPath;
  final LazyString _lazyMessage;
  final Lazy _lazyData;
  final LazyTags _lazyTags;

  Log(
    super.levelLogger, {
    required LazyString path,
    required Object message,
    required Object? data,
    required Object? tags,
    super.error,
    super.stackTrace,
    super.zone,
  })  : sequenceNum = ++_lastSequenceNum,
        time = clock.now(),
        _lazyPath = path,
        _lazyMessage = LazyString(message, ''),
        _lazyData = Lazy(data),
        _lazyTags = LazyTags(tags);

  String get path => _lazyPath.value;
  String get message => _lazyMessage.value;
  Object? get data => _lazyData.resolved;
  Set<String> get tags => _lazyTags.value;
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
