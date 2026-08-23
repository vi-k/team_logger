import 'package:example/readme_examples/frames.dart';
import 'package:example/readme_examples/init_log.dart';
import 'package:example/readme_examples/loggable/person2.dart';
import 'package:team_logger/team_logger.dart';

final frames = <String, LogFrame>{
  'active_1': _inactiveTheme,
  'active_2': _byLevel,
  'active_3': _byNamespace,
  'active_4': _byTrace,
  'active_5': _byTag,
  'active_6': _byCallback,
};

void main(List<String> args) => runFrames(frames, args);

/// Inactive logs are printed with the dimmed theme.
void _inactiveTheme() {
  initLog(inactiveTheme: LogMainTheme.defaultInactiveTheme);
  printLogs();
}

/// Logs from a level upwards are active.
void _byLevel() {
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeLevel: LogLevels.info,
  );
  printLogs();
}

/// One namespace is active.
void _byNamespace() {
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeNamespaces: {'net'},
  );
  printLogs();
}

/// Two trace id groups are active.
void _byTrace() {
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeTraceGroups: {'user', 'net'},
  );
  printLogs();
}

/// Logs carrying a tag are active.
void _byTag() {
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeTags: {'success'},
  );
  printLogs();
}

/// A callback decides what is active.
void _byCallback() {
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    isLogActive: (log) => log.hasData,
  );
  printLogs();
}

void printLogs() {
  const person = Person('John', 42);
  final netLog = log.copyWith(name: 'net');
  final traceId = TraceId.auto('user');
  final netTraceId = TraceId.auto('net');

  log.trace(traceId, () {
    log.i('Update user info');

    log.trace(netTraceId, () {
      netLog.d('request', data: person);
      netLog.d('response: [success][200 OK][/success]', tags: {'success'});
    });

    log.i('User info updated', tags: {'success'});
  });
}
