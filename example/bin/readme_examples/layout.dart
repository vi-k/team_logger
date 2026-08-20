import 'package:example/readme_examples/frames.dart';
import 'package:example/readme_examples/init_log.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:team_logger/team_logger.dart';

const _person = {
  'firstName': 'Alex',
  'lastName': 'Doe',
  'age': 30,
  'sex': 'male',
  'children': [
    {'name': 'Mary', 'age': 5},
    {'name': 'Bob', 'age': 2},
  ],
};

final frames = <String, LogFrame>{
  'layout_1': _logLayout,
  'layout_2': _singleLine,
  'layout_3': _hiddenKeyInfo,
  'layout_4': _stackTrace,
  'layout_5': _separateStackTrace,
  'layout_6': _logConstraints,
};

void main(List<String> args) => runFrames(frames, args);

/// Раскладка строки лога из отдельных элементов.
void _logLayout() {
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

  log.d('User info', traceId: TraceId.auto('user'), data: _person);
}

/// Всё в одну строку, без переноса.
void _singleLine() {
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
  log.d('User info', traceId: TraceId.auto('user'), data: _person);
}

/// Повторяющаяся служебная часть на строках продолжения.
void _hiddenKeyInfo() {
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(hiddenStyle: Styles.rgb050),
  );
  log.d('User info', traceId: TraceId.auto('user'), data: _person);
}

/// Стек внутри сообщения.
void _stackTrace() {
  initLog();
  someOperation();
}

/// Стек отдельной строкой со своей раскладкой.
void _separateStackTrace() {
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
}

/// Ограничения ширины колонок.
void _logConstraints() {
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
  log.d('User info', data: _person, traceId: traceId);
  // ignore: invalid_use_of_visible_for_testing_member
  Log.lastNum = 100;
  final networkLog = log.createChild(name: 'network');
  networkLog.d(
    '[b]PATCH[/b] http://example.com/[b]user[/b]',
    data: _person,
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
    log.d('Operation failed', error: error, stackTrace: _appFrames(stackTrace));
  }
}

/// Стек до машинерии съёмки.
///
/// Кадр исполняется из `runFrames` внутри `withClock`, и эти три кадра
/// (`runZoned`, `withClock`, `runFrames`) попадают в стек. К тому, что
/// показывает эта картинка — как раскладывается стек-трейс, — они
/// отношения не имеют, поэтому отрезаются. В приложении на их месте были
/// бы кадры его собственного фреймворка.
StackTrace _appFrames(StackTrace stackTrace) {
  final frames = Trace.from(stackTrace)
      .frames
      .takeWhile(
        (frame) =>
            frame.package != 'clock' && !frame.library.endsWith('frames.dart'),
      )
      .toList();

  // `runZoned` из `dart:async` стоит ровно перед ними.
  while (frames.isNotEmpty && frames.last.isCore) {
    frames.removeLast();
  }

  return Trace(frames);
}

int calcResult() {
  return 1 ~/ 0;
}
