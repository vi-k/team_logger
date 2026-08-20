import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

typedef Frame = FutureOr<void> Function();

/// Точка входа файла-группы примеров README.
///
/// - `--list` — печатает имена кадров, по одному на строку;
/// - `<имя кадра>` — исполняет один кадр под фиксированными часами;
/// - без аргументов — исполняет все кадры подряд, с заголовками.
///
/// Имя кадра — имя картинки в `screenshots/` без расширения.
Future<void> runFrames(Map<String, Frame> frames, List<String> args) async {
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

/// Часы кадра: старт в фиксированной точке, шаг на каждое обращение.
///
/// Время в логах растёт, как в настоящем прогоне, но пересъёмка даёт тот
/// же вывод — поэтому `.ansi` рядом с картинкой не «дрожит», а
/// `scripts/screenshots.sh --check` может сравнивать его как текст.
///
/// Шаг привязан к обращению к часам, а не к логу: если пакет спросит
/// время дважды на один лог, соседние строки разойдутся на два шага.
Clock _frameClock() {
  var tick = 0;
  final base = DateTime(2026, 3, 14, 9, 26, 53, 589);

  return Clock(() => base.add(Duration(milliseconds: 37 * tick++)));
}
