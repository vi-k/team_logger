import 'dart:async';

import 'package:logger_builder/logger_builder.dart';

import '../logger/logger.dart';

final class LogStorage implements CustomLogPublisher<Log> {
  final _controller = StreamController<void>.broadcast();

  final int maxCount;

  final List<Log?> _logs;
  int _currentIndex;
  int _count;

  LogStorage({required this.maxCount})
      : _logs = List<Log?>.filled(maxCount, null),
        _currentIndex = 0,
        _count = 0;

  Stream<void> get onUpdate => _controller.stream;

  int get count => _count;

  Log operator [](int index) {
    if (index < 0 || index >= _count) {
      throw IndexError.withLength(
        index,
        _count,
        indexable: this,
        name: 'LogStorage',
      );
    }
    final effectiveIndex = _currentIndex - _count + index;
    return _logs[
        effectiveIndex < 0 ? effectiveIndex + maxCount : effectiveIndex]!;
  }

  int indexOf(Log log) {
    var index = _logs.indexOf(log);
    if (index == -1) {
      return -1;
    }

    var startIndex = _currentIndex - _count;
    startIndex = startIndex < 0 ? startIndex + maxCount : startIndex;

    index -= startIndex;
    index = index < 0 ? index + maxCount : index;

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
    startIndex = startIndex < 0 ? startIndex + maxCount : startIndex;

    return startIndex < _currentIndex
        ? _logs.getRange(startIndex, _currentIndex).nonNulls.toList()
        : [
            ..._logs.getRange(startIndex, maxCount).nonNulls,
            ..._logs.getRange(0, _currentIndex).nonNulls,
          ];
  }

  void clear() {
    _logs.fillRange(0, maxCount, null);
    _currentIndex = 0;
    _count = 0;
    notifyListeners();
  }

  @override
  void publish(Log log) {
    _logs[_currentIndex] = log;
    _currentIndex = (_currentIndex + 1) % maxCount;
    _count = _count < maxCount ? _count + 1 : maxCount;
    notifyListeners();
  }
}
