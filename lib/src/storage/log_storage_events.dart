part of 'log_storage.dart';

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
