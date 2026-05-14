import 'dart:async';

import 'package:logger_builder/logger_builder.dart';

import '../logger/log_levels.dart';
import '../logger/logger.dart';

final class LogStorage implements CustomLogPublisher<Log> {
  final _onChangedController = StreamController<LogStorageEvent>.broadcast();

  final int maxCount;
  final int minLevel;
  final bool reverse;

  final List<Log?> _logs;
  int _currentIndex;
  int _count;

  LogStorage({
    required this.maxCount,
    this.minLevel = LogLevels.all,
    this.reverse = false,
  })  : _logs = List<Log?>.filled(maxCount, null),
        _currentIndex = 0,
        _count = 0;

  Stream<LogStorageEvent> get onChanged => _onChangedController.stream;

  int get count => _count;

  bool get isEmpty => _count == 0;

  bool get isNotEmpty => _count != 0;

  Log get first => this[0];

  Log? get firstOrNull => isEmpty ? null : first;

  Log get last => this[_count - 1];

  Log? get lastOrNull => isEmpty ? null : last;

  Log operator [](int index) {
    if (index < 0 || index >= _count) {
      throw IndexError.withLength(
        index,
        _count,
        indexable: this,
        name: 'LogStorage',
      );
    }

    var effectiveIndex =
        reverse ? _currentIndex - index - 1 : _currentIndex - _count + index;
    if (effectiveIndex < 0) effectiveIndex += maxCount;

    return _logs[effectiveIndex]!;
  }

  int _indexByEffectiveIndex(int effectiveIndex) {
    if (effectiveIndex == -1) return -1;

    int index;
    if (reverse) {
      index = _currentIndex - effectiveIndex - 1;
    } else {
      var startIndex = _currentIndex - _count;
      if (startIndex < 0) startIndex += maxCount;

      index = effectiveIndex - startIndex;
    }
    if (index < 0) index += maxCount;

    return index < _count ? index : -1;
  }

  int indexOf(Log log) => _indexByEffectiveIndex(_logs.indexOf(log));

  int indexBySequenceNum(int sequenceNum) => _indexByEffectiveIndex(
        _logs.indexWhere((log) => log?.sequenceNum == sequenceNum),
      );

  Future<void> dispose() => _onChangedController.close();

  List<Log> snapshot() {
    final count = _count;
    if (count == 0) return List.empty();

    var startIndex = _currentIndex - _count;
    if (startIndex < 0) startIndex += maxCount;

    final list = (startIndex < _currentIndex
            ? _logs.getRange(startIndex, _currentIndex).nonNulls
            : _logs
                .getRange(startIndex, maxCount)
                .followedBy(_logs.getRange(0, _currentIndex))
                .nonNulls)
        .toList();

    if (reverse) {
      final half = count ~/ 2;
      for (var i = 0; i < half; i++) {
        final tmp = list[i];
        final i2 = count - i - 1;
        list[i] = list[i2];
        list[i2] = tmp;
      }
    }

    return list;
  }

  void clear() {
    _logs.fillRange(0, maxCount, null);
    _currentIndex = 0;
    _count = 0;

    _onChangedController.add(const LogStorageClear._());
  }

  @override
  void publish(Log log) {
    if (log.level < minLevel) {
      return;
    }

    final oldLog = _logs[_currentIndex];
    _logs[_currentIndex] = log;
    _currentIndex = (_currentIndex + 1) % maxCount;

    _onChangedController.add(LogStorageAdd._(log));

    if (_count < maxCount) {
      _count++;
    } else if (oldLog != null) {
      _onChangedController.add(LogStorageRemove._(oldLog));
    }
  }
}

sealed class LogStorageEvent {
  const LogStorageEvent();
}

final class LogStorageAdd extends LogStorageEvent {
  final Log log;

  const LogStorageAdd._(this.log);
}

final class LogStorageRemove extends LogStorageEvent {
  final Log log;

  const LogStorageRemove._(this.log);
}

final class LogStorageClear extends LogStorageEvent {
  const LogStorageClear._();
}
