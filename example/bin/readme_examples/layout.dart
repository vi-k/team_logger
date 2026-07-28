import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:example/readme_examples/init_log.dart';
import 'package:team_logger/team_logger.dart';

Future<void> main() async {
  const person = {
    'firstName': 'Alex',
    'lastName': 'Doe',
    'age': 30,
    'sex': 'male',
    'children': [
      {'name': 'Mary', 'age': 5},
      {'name': 'Bob', 'age': 2},
    ],
  };

  print('----- Log layout -----');
  initLog(
    rows: [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );

  log.d('User info', traceId: TraceId.auto('user'), data: person);

  print('----- Single line -----');
  initLog(
    rows: [
      LogRow.singleLine(
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );
  log.d('User info', traceId: TraceId.auto('user'), data: person);

  print('----- Hidden key info -----');
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(hiddenStyle: ansi.rgb050),
  );
  log.d('User info', traceId: TraceId.auto('user'), data: person);

  print('----- Stack trace -----');
  initLog();
  someOperation();

  print('----- Separate stack trace -----');
  initLog(
    rows: [
      const LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(showStackTrace: false),
        ],
        tail: [LogTags()],
      ),
      LogRow(
        when: (log) => log.stackTrace != null,
        maxLength: 100,
        children: [
          // We remove any unnecessary information, keeping only the sequence
          // number, but visually hiding it (by default, the first line is
          // visible).
          LogNum(hidden: true),
          LogStackTrace(),
        ],
        // We'll keep the tags, but hide them.
        tail: [LogTags(hidden: true)],
      ),
    ],
  );
  someOperation();

  print('----- LogConstraints -----');
  initLog(
    level: LogLevels.debug,
    theme: LogMainTheme.defaultActiveTheme.copyWith(padding: '.'),
    rows: [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(
            // Reserving space for numbering
            constraints: LogConstraints(min: 7),
            // Align to the right
            textAlign: LogTextAlign.right,
          ),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(
            // We make the space for the namespace path expand as new data is
            // added, but we do not limit its growth
            constraints: LogConstraints.growable(max: 20),
          ),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );
  final traceId = TraceId.auto('user');
  log.d('User info', data: person, traceId: traceId);
  // ignore: invalid_use_of_visible_for_testing_member
  Log.lastNum = 100;
  final networkLog = log.createChild(name: 'network');
  networkLog.d(
    '[b]PATCH[/b] http://example.com/[b]user[/b]',
    data: person,
    traceId: traceId,
  );
  // ignore: invalid_use_of_visible_for_testing_member
  Log.lastNum = 10000;
  log.d('User info succesfully patched', traceId: traceId);
}

void someOperation() {
  try {
    calcResult();
  } on Object catch (error, stackTrace) {
    log.d('Operation failed', error: error, stackTrace: stackTrace);
  }
}

int calcResult() {
  return 1 ~/ 0;
}
