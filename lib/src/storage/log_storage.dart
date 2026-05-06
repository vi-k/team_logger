import 'dart:async';

import 'package:logger_builder/logger_builder.dart';

import '../logger/log_levels.dart';
import '../logger/logger.dart';

final class LogStorage implements CustomLogPublisher<Log> {
  final _controller = StreamController<void>.broadcast();

  final int maxCount;
  final int minLevel;

  final List<Log?> _logs;
  int _currentIndex;
  int _count;

  LogStorage({
    required this.maxCount,
    this.minLevel = LogLevels.all,
  })  : _logs = List<Log?>.filled(maxCount, null),
        _currentIndex = 0,
        _count = 0;

  Stream<void> get onUpdate => _controller.stream;

  int get count => _count;

  bool get isEmpty => _count == 0;

  bool get isNotEmpty => _count != 0;

  Log get first => this[0];

  Log? get firstOrNull => isEmpty ? null : this[0];

  Log get last => this[_count - 1];

  Log? get lastOrNull => isEmpty ? null : this[_count - 1];

  Log operator [](int index) {
    if (index < 0 || index >= _count) {
      throw IndexError.withLength(
        index,
        _count,
        indexable: this,
        name: 'LogStorage',
      );
    }

    var effectiveIndex = _currentIndex - index - 1;
    if (effectiveIndex < 0) effectiveIndex += maxCount;

    return _logs[effectiveIndex]!;
  }

  int indexOf(Log log) {
    var index = _logs.indexOf(log);
    if (index == -1) {
      return -1;
    }

    index = _currentIndex - index - 1;
    if (index < 0) index += maxCount;

    return index < _count ? index : -1;
  }

  Future<void> dispose() => _controller.close();

  void notifyListeners() {
    if (_controller.hasListener) {
      _controller.add(null);
    }
  }

  List<Log> snapshot() {
    var startIndex = _currentIndex - _count;
    if (startIndex < 0) startIndex += maxCount;

    if (startIndex == _currentIndex) return List.empty();

    final iterable = startIndex < _currentIndex
        ? _logs.getRange(startIndex, _currentIndex).nonNulls
        : _logs
            .getRange(startIndex, maxCount)
            .followedBy(_logs.getRange(0, _currentIndex))
            .nonNulls;
    final count = _count;
    final list = List<Log>.filled(count, _logs[startIndex]!);
    for (final (i, log) in iterable.indexed) {
      list[count - i - 1] = log;
    }

    return list;
  }

  void clear() {
    _logs.fillRange(0, maxCount, null);
    _currentIndex = 0;
    _count = 0;
    notifyListeners();
  }

  @override
  void publish(Log log) {
    if (log.level < minLevel) {
      return;
    }

    _logs[_currentIndex] = log;
    _currentIndex = (_currentIndex + 1) % maxCount;
    _count = _count < maxCount ? _count + 1 : maxCount;
    notifyListeners();
  }
}
