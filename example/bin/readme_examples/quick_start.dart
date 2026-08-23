import 'package:example/readme_examples/frames.dart';
import 'package:team_logger/team_logger.dart';

final frames = <String, LogFrame>{
  'quick_start_1': _quickStart,
  'quick_start_2': _filterByNum,
  'quick_start_3': _filterByTraceId,
  'quick_start_4': _filterByTag,
};

void main(List<String> args) => runFrames(frames, args);

late Logger log;

/// Builds the application's logger; [when] decides which logs reach the
/// frame.
///
/// Frames 2-4 show one and the same run with only part of its logs printed.
/// What filters them is the layout row ([LogRow.when]), not the logger:
/// every log is still created, so the numbers in a frame keep their
/// original order.
void _initLog({bool Function(Log log)? when}) {
  log = Logger('app', tags: {'log'})
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.defaultActiveTheme,
      rows: [
        LogRow(
          when: when,
          maxLength: 120,
          children: const [
            LogNum(),
            LogLevelName.short(),
            LogTime.onlyTime(),
            LogPath(),
            LogTraceId(),
            LogMessage(),
          ],
          tail: const [
            LogTags(),
          ],
        ),
      ],
    );
}

/// One payment end to end: the start, the child loggers, the trace zone.
Future<void> _quickStart() async {
  _initLog();
  await _payment();

  print(Styles.rgb311('''
 ┬   ┬                ┬──────────   ┬────────  ──────┬────────────────────────────────────────────╯ ╰──────────────────┬
 │   ╰─ level         │             ╰─ trace ID      ╰─ message with data                                        tags ─╯
 ╰─ sequence number   ╰─ namespace path

╰─────────────────────────────────────────────────── maxLength: 120 ───────────────────────────────────────────────────╯'''));
}

/// The same run, with the printer keeping one log by its number.
Future<void> _filterByNum() async {
  print(_filterBox('(4)'));
  _initLog(when: (log) => log.num == 4);
  await _payment();
}

/// ...by trace id group.
Future<void> _filterByTraceId() async {
  print(_filterBox('{payment-1}'));
  _initLog(when: (log) => log.traceIds.isNotEmpty);
  await _payment();
}

/// ...by tag.
Future<void> _filterByTag() async {
  print(_filterBox('#http'));
  _initLog(when: (log) => log.tags.contains('http'));
  await _payment();
}

Future<void> _payment() async {
  log.i('App started');

  // Create child loggers
  final paymentLog = log.createChild(name: 'payment');

  // Execute within a Trace Zone to automatically capture and output the
  // TraceId
  await log.trace(TraceId.auto('payment'), () async {
    paymentLog.i('Initiating payment request...');
    await _request(10, 'USD');
    paymentLog.i('Payment processed successfully');
  });
}

Future<void> _request(int amount, String currency) async {
  final networkLog = log.createChild(name: 'network', tags: {'http'});

  networkLog.d(
    'https://api.example.com/[b]v1/payment[/b]',
    tags: ['request'],
    data: {'amount': amount, 'currency': currency},
  );

  // ... api call ...

  networkLog.d(
    '[success][200 OK][/success] https://api.example.com/[b]v1/payment[/b]',
    tags: ['response'],
    data: {'payment_id': 123},
  );
}

/// The "Filter: ..." box above a frame: what the run was filtered by.
String _filterBox(String value) => Styles.rgb122(
      '                                                                                  ╭────────────────────────────────────╮\n'
      '                                                                          Filter: │ ${value.padRight(35)}│\n'
      '                                                                                  ╰────────────────────────────────────╯',
    );
