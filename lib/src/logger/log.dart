part of 'logger.dart';

final class LogNoData {
  const LogNoData._();

  @override
  String toString() => '<no data>';
}

final class Log extends CustomLog with Loggable {
  @visibleForTesting
  static int lastNum = 0;
  static const noData = LogNoData._();

  final DateTime time;
  final int num;
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
  })  : num = ++lastNum,
        time = clock.now();

  bool get hasData => data is! LogNoData;

  Set<String?> get traceIdGroups => traceIds.map((e) => e.group).toSet();

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('num', num)
      ..prop('level', level, view: levelName)
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
      data.computed('hasData', true);
    }
    if (error != null) {
      data.computed('hasError', true);
    }
    if (stackTrace != null) {
      data.computed('hasStackTrace', true);
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
        // Тип элементов проверяется поэлементно: Iterable<String>() матчит
        // только коллекции, типизированные строкой, и List<Object> со
        // строками ронял бы вызов логирования.
        Iterable<Object?>() => {
            for (final tag in resolved)
              if (tag != null) tag.toString(),
          },
        _ => throw Exception('Invalid tags: $resolved'),
      };
}
