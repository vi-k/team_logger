import 'package:ansi_escape_codes/extensions.dart';
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
        normal: Styles.rgb030,
        emphasis: Styles.rgb252,
        dim: Styles.dim,
        punctuation: Styles.rgb550,
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
            brackets: Styles.gray20,
            punctuation: Styles.gray20,
            description: Styles.gray20,
          ),
          LogDepthTheme(
            brackets: Styles.gray16,
            punctuation: Styles.gray16,
            description: Styles.gray16,
          ),
          LogDepthTheme(
            brackets: Styles.gray12,
            punctuation: Styles.gray12,
            description: Styles.gray12,
          ),
          LogDepthTheme(
            brackets: Styles.gray8,
            punctuation: Styles.gray8,
            description: Styles.gray8,
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
