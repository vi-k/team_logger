import 'package:example/readme_examples/default_log.dart';
import 'package:example/readme_examples/frames.dart';
import 'package:team_logger/team_logger.dart';

final frames = <String, LogFrame>{
  'trace_1': _searchTrace,
  'trace_2': _traceIdConfigurations,
  'trace_3': _traceIdWithSuffix,
  'trace_4': _laziness,
};

void main(List<String> args) => runFrames(frames, args);

/// `log.trace` around an asynchronous stretch: both logs inside pick up
/// the same trace id.
Future<void> _searchTrace() async {
  final searchTrace = TraceId.auto('search'); // resolves to 'search-1'

  await log.trace(searchTrace, () async {
    log.d('Searching database...'); // captures and outputs 'search-1'
    await Future<void>.delayed(const Duration(milliseconds: 100));
    log.i('Database fetch completed'); // captures and outputs 'search-1'
  });
}

/// Three ways to set a trace id.
void _traceIdConfigurations() {
  log.d('Global', traceId: TraceId.global());
  log.d('Auto', traceId: TraceId.auto('group'));
  log.d('Manual', traceId: const TraceId.manual('group', 123));
}

/// Retries of one request under a single id with a suffix.
Future<void> _traceIdWithSuffix() => _request(Uri.parse('https://example.com'));

Future<void> _request(Uri uri) async {
  final traceId = TraceId.auto('request');

  log.i('$uri', traceId: traceId);
  // ... request ...

  // if request failed, retry:
  for (var i = 0; i < 3; i++) {
    log.w('$uri. Attempt #${i + 2}', traceId: traceId.withSuffix('${i + 2}'));
    // ... retry ...
  }
}

/// Numbering is lazy: a disabled level consumes no number.
void _laziness() {
  log.level = LogLevels.all;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // lazy-1
  log.i('Info message', traceId: TraceId.auto('lazy')); // lazy-2
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-3

  log.level = LogLevels.warning;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // not displayed
  log.i('Info message', traceId: TraceId.auto('lazy')); // not displayed
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-4

  print(
    Styles.rgb311('''
                            ─────┬
                                 ╰─ lazy-4, not lazy-6'''),
  );
}
