import 'package:team_logger/team_logger.dart';

// Initialize the logger with a custom layout
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 120,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [
          LogTags(),
        ],
      ),
    ],
  );

Future<void> main() async {
  // For README: add filter field
  // print(
  //   Styles.rgb122('''
  //                                                                                 ╭────────────────────────────────────╮
  //                                                                         Filter: │ (4)                                │
  //                                                                                 ╰────────────────────────────────────╯'''),
  // );

  log.i('App started');

  // Create child loggers
  final paymentLog = log.createChild(name: 'payment');

  // Execute within a Trace Zone to automatically capture and output the TraceId
  await log.trace(TraceId.auto('payment'), () async {
    paymentLog.i('Initiating payment request...');
    await payment(10, 'USD');
    paymentLog.i('Payment processed successfully');
  });

// For README: add description of log line
//   print(
//     Styles.rgb311('''
//  ┬   ┬                ┬──────────   ┬────────  ──────┬────────────────────────────────────────────╯ ╰──────────────────┬
//  │   ╰─ level         │             ╰─ trace ID      ╰─ message with data                                        tags ─╯
//  ╰─ sequence number   ╰─ namespace path

// ╰─────────────────────────────────────────────────── maxLength: 120 ───────────────────────────────────────────────────╯'''),
//   );
}

Future<void> payment(int amount, String currency) async {
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
