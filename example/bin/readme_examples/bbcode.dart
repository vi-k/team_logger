import 'package:example/readme_examples/frames.dart';
import 'package:example/readme_examples/init_log.dart';
import 'package:team_logger/team_logger.dart';

final frames = <String, LogFrame>{
  'bbcode_1': _bbCodes,
  'bbcode_2': _userDefinedTags,
  'bbcode_3': _logLazyStyle,
  'bbcode_4': _noColors,
  'bbcode_5': _noColorsNoTags,
  'bbcode_6': _noColorsNoTagsTheme,
};

void main(List<String> args) => runFrames(frames, args);

/// Встроенные bb-коды.
void _bbCodes() {
  initLog();
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [success]success[/success] text');
  log.d(
    'This is a [warning]warning[/warning] text within the not-warning text',
  );
  log.d('This is a [error]error[/error] text within the not-error text');
  log.d('This is a [signal]signal[/signal] to get attention');
}

/// Свои теги оформления.
void _userDefinedTags() {
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      messageStyles: {
        'b': LogStyle(Styles.bold),
        'i': LogStyle(Styles.italic),
        's': LogStyle(Styles.strikethrough),
        'u': LogStyle(Styles.underline),
      },
    ),
  );
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [i]italic[/i] text');
  log.d('This is a [s]strikethrough[/s] text');
  log.d('This is a [u]underline[/u] text');
}

/// Стиль, вычисляемый по теме.
void _logLazyStyle() {
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      messageStyles: {
        'fatal': LogLazyStyle((theme) => theme.main.critical.data.normal),
      },
    ),
  );
  log.d('This is [fatal]a fatal error[/fatal]');
}

/// Бесцветная тема: теги остаются, оформления нет.
void _noColors() {
  initLog(theme: LogMainTheme.noColors);
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [i]italic[/i] text');
  log.d('This is a [s]strikethrough[/s] text');
  log.d('This is a [u]underline[/u] text');
}

/// Теги погашены поимённо.
void _noColorsNoTags() {
  initLog(
    theme: LogMainTheme.noColors.copyWith(
      messageStyles: const {
        'b': LogNoStyle(),
        'i': LogNoStyle(),
        's': LogNoStyle(),
        'u': LogNoStyle(),
      },
    ),
  );
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [i]italic[/i] text');
  log.d('This is a [s]strikethrough[/s] text');
  log.d('This is a [u]underline[/u] text');
}

/// Готовая тема `noColorsNoTags` — то же самое одной строкой.
void _noColorsNoTagsTheme() {
  initLog(theme: LogMainTheme.noColorsNoTags);
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [success]success[/success] text');
  log.d('This is a [warning]warning[/warning] text');
  log.d('This is a [error]error[/error] text');
  log.d('This is a [signal]signal[/signal]');
}
