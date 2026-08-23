import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

typedef LogFrame = FutureOr<void> Function();

/// The entry point of a README example group file.
///
/// - `--list` prints the frame names, one per line;
/// - `<frame name>` runs one frame under a fixed clock;
/// - with no arguments every frame runs in turn, with headings.
///
/// A frame's name is the name of its picture in `screenshots/`, without the
/// extension.
Future<void> runFrames(Map<String, LogFrame> frames, List<String> args) async {
  if (args.contains('--list')) {
    frames.keys.forEach(print);

    return;
  }

  if (args.isEmpty) {
    for (final MapEntry(key: name, value: frame) in frames.entries) {
      print('----- $name -----');
      await frame();
    }

    return;
  }

  final name = args.first;
  final frame = frames[name];
  if (frame == null) {
    stderr.writeln('Unknown frame: $name. Known: ${frames.keys.join(', ')}');
    exitCode = 2;

    return;
  }

  await withClock(_frameClock(), frame);
}

/// A frame's clock: it starts at a fixed point and ticks on every read.
///
/// Time in the logs advances as it would in a real run, yet re-shooting
/// gives the same output — which is why the `.ansi` beside a picture does
/// not jitter and `scripts/screenshots.sh --check` can compare it as text.
///
/// The tick is tied to reading the clock, not to a log: if the package asks
/// for the time twice for one log, neighbouring lines drift apart by two
/// ticks.
Clock _frameClock() {
  var tick = 0;
  final base = DateTime(2026, 3, 14, 9, 26, 53, 589);

  return Clock(() => base.add(Duration(milliseconds: 37 * tick++)));
}
