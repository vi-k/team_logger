part of 'logger.dart';

final class LogNoData {
  const LogNoData._();

  @override
  String toString() => '<no data>';
}

final class Log extends CustomLog with Loggable {
  static int _lastSequenceNum = 0;
  static const noData = LogNoData._();

  final DateTime time;
  final int sequenceNum;
  final String path;
  final List<TraceId> traceIds;
  final String message;
  final Object? data;
  final Set<String> tags;

  Log(
    super.levelLogger, {
    required this.path,
    required this.traceIds,
    required this.message,
    required this.data,
    required this.tags,
    super.error,
    super.stackTrace,
    super.zone,
  })  : sequenceNum = ++_lastSequenceNum,
        time = clock.now();

  bool get hasData => data is! LogNoData;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('sequenceNum', sequenceNum, showName: false, view: '#$sequenceNum')
      ..prop('level', level, view: levelName)
      ..hidden('levelName', levelName)
      ..hidden('shortLevelName', shortLevelName)
      ..prop('time', time)
      ..prop('path', path);

    if (traceIds.isNotEmpty) {
      data.prop('traceIds', traceIds);
    }
    data.prop('message', message);

    if (tags.isNotEmpty) {
      data.prop('tags', tags);
    }
    if (hasData) {
      data.prop('hasData', true);
    }
    if (error != null) {
      data.prop('hasError', true);
    }
    if (stackTrace != null) {
      data.prop('hasStackTrace', true);
    }
  }
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
