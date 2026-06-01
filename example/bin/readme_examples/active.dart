import 'package:example/readme_examples/init_log.dart';
import 'package:example/readme_examples/loggable/person2.dart';
import 'package:team_logger/team_logger.dart';

void main() {
  print('----- Inactive theme -----');
  initLog(inactiveTheme: LogMainTheme.defaultInactiveTheme, maxLength: 120);
  printLogs();

  print('----- By level -----');
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeLevel: LogLevels.info,
    maxLength: 120,
  );
  printLogs();

  print('----- By logger -----');
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    maxLength: 120,
    activeLoggers: {'net'},
  );
  printLogs();

  print('----- By trace -----');
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    maxLength: 120,
    activeTraceGroups: {'user', 'net'},
  );
  printLogs();

  print('----- By tag -----');
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    maxLength: 120,
    activeTags: {'success'},
  );
  printLogs();

  print('----- By callback -----');
  initLog(
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    maxLength: 120,
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
