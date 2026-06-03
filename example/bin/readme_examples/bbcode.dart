import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:example/readme_examples/init_log.dart';
import 'package:team_logger/team_logger.dart';

void main() {
  print('----- BBCodes -----');
  initLog();
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [success]success[/success] text');
  log.d(
    'This is a [warning]warning[/warning] text within the not-warning text',
  );
  log.d('This is a [error]error[/error] text within the not-error text');
  log.d('This is a [signal]signal[/signal] to get attention');

  print('----- User defined tags -----');
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      messageStyles: {
        'b': LogStyle(ansi.bold),
        'i': LogStyle(ansi.italic),
        's': LogStyle(ansi.strikethrough),
        'u': LogStyle(ansi.underline),
      },
    ),
  );
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [i]italic[/i] text');
  log.d('This is a [s]strikethrough[/s] text');
  log.d('This is a [u]underline[/u] text');

  print('----- LogLazyStyle -----');
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      messageStyles: {
        'fatal': LogLazyStyle((theme) => theme.main.critical.data.normal),
      },
    ),
  );
  log.d('This is [fatal]a fatal error[/fatal]');

  print('----- No Colors -----');
  initLog(theme: LogMainTheme.noColors);
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [i]italic[/i] text');
  log.d('This is a [s]strikethrough[/s] text');
  log.d('This is a [u]underline[/u] text');

  print('----- No Colors, no tags -----');
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

  initLog(theme: LogMainTheme.noColorsNoTags);
  log.d('This is a [b]bold[/b] text');
  log.d('This is a [success]success[/success] text');
  log.d('This is a [warning]warning[/warning] text');
  log.d('This is a [error]error[/error] text');
  log.d('This is a [signal]signal[/signal]');
}
