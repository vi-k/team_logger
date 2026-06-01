import 'package:ansi_escape_codes/extensions.dart';
import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:example/readme_examples/init_log.dart';
import 'package:team_logger/team_logger.dart';

void main() {
  const person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};

  print('----- Color theme -----');
  initLog();
  log.i('color theme', data: person);

  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(info: LogThemeData.rgb122),
  );
  log.i('color theme', data: person);

  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      info: LogThemeData.seed(
        normal: ansi.rgb030,
        emphasis: ansi.rgb252,
        dim: ansi.dim,
        punctuation: ansi.rgb550,
        messageStyles: LogThemeData.defaultMessageStyles,
        depthThemes: LogDepthTheme.defaultThemesWoYellowAndGreen,
      ),
    ),
  );
  log.i('color theme', data: person);

  print('----- Depth themes -----');
  const deeplyNested = [
    123,
    [
      234,
      [
        345,
        [456],
      ],
    ],
  ];

  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      info: LogMainTheme.defaultActiveTheme.info.data.copyWith(
        depthThemes: [
          LogDepthTheme.yellow,
          LogDepthTheme.orange,
          LogDepthTheme.magenta,
          LogDepthTheme.red,
        ],
      ),
    ),
  );

  log.i('depth themes', data: deeplyNested);
  initLog(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      info: LogMainTheme.defaultActiveTheme.info.data.copyWith(
        depthThemes: [
          LogDepthTheme(
            brackets: ansi.gray20,
            punctuation: ansi.gray20,
            description: ansi.gray20,
          ),
          LogDepthTheme(
            brackets: ansi.gray16,
            punctuation: ansi.gray16,
            description: ansi.gray16,
          ),
          LogDepthTheme(
            brackets: ansi.gray12,
            punctuation: ansi.gray12,
            description: ansi.gray12,
          ),
          LogDepthTheme(
            brackets: ansi.gray8,
            punctuation: ansi.gray8,
            description: ansi.gray8,
          ),
        ],
      ),
    ),
  );
  log.i('depth themes', data: deeplyNested);

  print('----- No color theme -----');
  initLog(theme: LogMainTheme.noColors);
  log.d('no colors', data: person);

  // No ANSI escape codes.
  initLog(
    theme: LogMainTheme.noColors,
    output: (str) => print(str.ansiShowEscapeSequences()),
  );
  log.d('no colors', data: person);
}
