import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:example/readme_examples/log.dart';
import 'package:team_logger/team_logger.dart';

Future<void> main() async {
  print('----- Example with log.trace -----');
  final searchTrace = TraceId.auto('search'); // resolves to '#search-1'

  await log.trace(searchTrace, () async {
    log.d('Searching database...'); // captures and outputs '#search-1'
    await Future<void>.delayed(const Duration(milliseconds: 100));
    log.i('Database fetch completed'); // captures and outputs '#search-1'
  });

  print('----- TraceId configurations -----');
  log.d('Global', traceId: TraceId.global());
  log.d('Auto', traceId: TraceId.auto('group'));
  log.d('Manual', traceId: const TraceId.manual('group', 123));

  print('----- TraceId with suffix -----');
  await request(Uri.parse('https://example.com'));

  print('----- Laziness of TraceId -----');
  log.level = LogLevels.all;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // lazy-1
  log.i('Info message', traceId: TraceId.auto('lazy')); // lazy-2
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-3

  log.level = LogLevels.warning;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // not displayed
  log.i('Info message', traceId: TraceId.auto('lazy')); // not displayed
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-4

  // For README: add description
  // print(
  //   ansi.rgb311('''
  //                           ─────┬
  //                                ╰─ lazy-4, not lazy-6'''),
  // );
}

Future<dynamic> request(Uri uri) async {
  final traceId = TraceId.auto('request');

  log.i('$uri', traceId: traceId);
  // ... request ...

  // if request failed, retry:
  for (var i = 0; i < 3; i++) {
    log.w('$uri. Attempt #${i + 2}', traceId: traceId.withSuffix('${i + 2}'));
    // ... retry ...
  }
}
