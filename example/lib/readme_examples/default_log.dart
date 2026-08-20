import 'package:format/format.dart';
import 'package:team_logger/team_logger.dart';

final log = Logger('app', tags: {'log'})
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      numberFormatter: (theme, value, pattern) => format(pattern, value),
    ),
    rows: const [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );
