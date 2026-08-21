import 'dart:async';

import 'package:logger_builder/logger_builder.dart';

import '../logger/log_levels.dart';
import '../logger/logger.dart';

part 'log_storage_events.dart';

/// An in-memory circular buffer of the last [maxCount] logs.
///
/// Designed for in-app log inspection and diagnostics export. [onChanged]
/// emits [LogStorageAdd] for every accepted log and, when an old log is
/// evicted, a following [LogStorageRemove] (add first, then remove —
/// a mirroring subscriber transiently holds `maxCount + 1` entries).
/// After [dispose] the storage ignores [publish] and [clear].
///
/// Construction throws [ArgumentError] when [maxCount] is not positive.
abstract interface class LogStorage implements CustomLogPublisher<Log> {
  factory LogStorage({
    required int maxCount,
    int minLevel,
  }) = _LogStorageImpl;

  LogStorage get reversed;

  int get maxCount;

  int get minLevel;

  Stream<LogStorageEvent> get onChanged;

  int get count;

  bool get isEmpty;

  bool get isNotEmpty;

  Log get first;

  Log? get firstOrNull;

  Log get last;

  Log? get lastOrNull;

  Log operator [](int index);

  int indexOf(Log log);

  int indexByNum(int logNum);

  Future<void> dispose();

  List<Log> snapshot();

  void clear();
}

final class _LogStorageImpl implements LogStorage {
  final _onChangedController = StreamController<LogStorageEvent>.broadcast();

  @override
  final int maxCount;

  @override
  final int minLevel;

  final List<Log?> _logs;
  int _currentIndex;
  int _count;

  _LogStorageImpl({
    required this.maxCount,
    this.minLevel = LogLevels.all,
  })  : _logs = _createLogBuffer(maxCount),
        _currentIndex = 0,
        _count = 0;

  @override
  LogStorage get reversed => _ReversedLogStorageImpl(this);

  @override
  Stream<LogStorageEvent> get onChanged => _onChangedController.stream;

  @override
  int get count => _count;

  @override
  bool get isEmpty => _count == 0;

  @override
  bool get isNotEmpty => _count != 0;

  @override
  Log get first => this[0];

  @override
  Log? get firstOrNull => isEmpty ? null : first;

  @override
  Log get last => this[_count - 1];

  @override
  Log? get lastOrNull => isEmpty ? null : last;

  @override
  Log operator [](int index) {
    if (index < 0 || index >= _count) {
      throw IndexError.withLength(
        index,
        _count,
        indexable: this,
        name: 'LogStorage',
      );
    }

    var effectiveIndex = _currentIndex - _count + index;
    if (effectiveIndex < 0) effectiveIndex += maxCount;

    return _logs[effectiveIndex]!;
  }

  int _indexByEffectiveIndex(int effectiveIndex) {
    if (effectiveIndex == -1) return -1;

    var startIndex = _currentIndex - _count;
    if (startIndex < 0) startIndex += maxCount;

    var index = effectiveIndex - startIndex;

    if (index < 0) index += maxCount;

    return index < _count ? index : -1;
  }

  @override
  int indexOf(Log log) => _indexByEffectiveIndex(_logs.indexOf(log));

  @override
  int indexByNum(int logNum) => _indexByEffectiveIndex(
        _logs.indexWhere((log) => log?.num == logNum),
      );

  @override
  Future<void> dispose() => _onChangedController.close();

  @override
  List<Log> snapshot() {
    final count = _count;
    if (count == 0) return <Log>[];

    final currentIndex = _currentIndex;
    var startIndex = currentIndex - _count;
    if (startIndex < 0) startIndex += maxCount;

    final list = (startIndex < currentIndex
            ? _logs.getRange(startIndex, currentIndex).nonNulls
            : _logs
                .getRange(startIndex, maxCount)
                .followedBy(_logs.getRange(0, currentIndex))
                .nonNulls)
        .toList();

    return list;
  }

  @override
  void clear() {
    // После dispose хранилище не используется.
    if (_onChangedController.isClosed) return;

    _logs.fillRange(0, maxCount, null);
    _currentIndex = 0;
    _count = 0;

    _onChangedController.add(const LogStorageClear._());
  }

  @override
  void publish(Log log) {
    // После dispose публикация — no-op: иначе StateError вылетал бы
    // прямо из вызова логирования.
    if (_onChangedController.isClosed) return;

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

List<Log?> _createLogBuffer(int maxCount) {
  if (maxCount <= 0) {
    throw ArgumentError.value(maxCount, 'maxCount', 'Must be positive');
  }

  return List<Log?>.filled(maxCount, null);
}

final class _ReversedLogStorageImpl implements LogStorage {
  final _LogStorageImpl _storage;

  _ReversedLogStorageImpl(this._storage);

  @override
  LogStorage get reversed => _storage;

  @override
  int get maxCount => _storage.maxCount;

  @override
  int get minLevel => _storage.minLevel;

  @override
  Stream<LogStorageEvent> get onChanged => _storage.onChanged;

  @override
  int get count => _storage.count;

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  Log get first => _storage.last;

  @override
  Log? get firstOrNull => _storage.lastOrNull;

  @override
  Log get last => _storage.first;

  @override
  Log? get lastOrNull => _storage.firstOrNull;

  @override
  Log operator [](int index) {
    if (index < 0 || index >= _storage._count) {
      throw IndexError.withLength(
        index,
        _storage._count,
        indexable: this,
        name: 'LogStorage',
      );
    }

    var effectiveIndex = _storage._currentIndex - index - 1;
    if (effectiveIndex < 0) effectiveIndex += maxCount;

    return _storage._logs[effectiveIndex]!;
  }

  int _indexByEffectiveIndex(int effectiveIndex) {
    if (effectiveIndex == -1) return -1;

    var index = _storage._currentIndex - effectiveIndex - 1;
    if (index < 0) index += maxCount;

    return index < _storage._count ? index : -1;
  }

  @override
  int indexOf(Log log) => _indexByEffectiveIndex(_storage._logs.indexOf(log));

  @override
  int indexByNum(int logNum) => _indexByEffectiveIndex(
        _storage._logs.indexWhere((log) => log?.num == logNum),
      );

  @override
  Future<void> dispose() => _storage.dispose();

  @override
  List<Log> snapshot() {
    final list = _storage.snapshot();
    final half = count ~/ 2;
    for (var i = 0; i < half; i++) {
      final tmp = list[i];
      final i2 = count - i - 1;
      list[i] = list[i2];
      list[i2] = tmp;
    }

    return list;
  }

  @override
  void clear() => _storage.clear();

  @override
  void publish(Log log) => _storage.publish(log);
}
