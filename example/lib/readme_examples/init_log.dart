import 'package:team_logger/team_logger.dart';

late Logger log;

void initLog({
  int? level,
  LogMainTheme? theme,
  LogMainTheme? inactiveTheme,
  void Function(String)? output,
  int? activeLevel,
  Set<String>? activeLoggers,
  Set<String>? activeTraceGroups,
  Set<String>? activeTags,
  bool Function(Log log)? isLogActive,
  int? maxLength,
  List<LogRow>? rows,
}) {
  log = Logger('app')
    ..level = level ?? LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme ?? LogMainTheme.defaultActiveTheme,
      inactiveTheme: inactiveTheme,
      output: output ?? print,
      activeLevel: activeLevel,
      activeLoggers: activeLoggers,
      activeTraceGroups: activeTraceGroups,
      activeTags: activeTags,
      isLogActive: isLogActive,
      rows:
          rows ??
          [
            LogRow(
              maxLength: maxLength ?? 100,
              children: [
                LogSequenceNum(),
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
}
