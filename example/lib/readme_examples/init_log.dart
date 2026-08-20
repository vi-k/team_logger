import 'package:team_logger/team_logger.dart';

late Logger log;

void initLog({
  int? level,
  LogMainTheme? theme,
  LogMainTheme? inactiveTheme,
  void Function(String)? output,
  int? activeLevel,
  Set<String>? activeNamespaces,
  Set<String>? activeTraceGroups,
  Set<String>? activeTags,
  bool Function(Log log)? isLogActive,
  int? maxLength,
  List<LogRow>? rows,
}) {
  log = Logger('app', tags: {'log'})
    ..level = level ?? LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme ?? LogMainTheme.defaultActiveTheme,
      inactiveTheme: inactiveTheme,
      output: output ?? print,
      activeMinLevel: activeLevel,
      activeNamespaces: activeNamespaces,
      activeTraceGroups: activeTraceGroups,
      activeTags: activeTags,
      isLogActive: isLogActive,
      rows: rows ??
          [
            LogRow(
              maxLength: maxLength ?? 100,
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
}
