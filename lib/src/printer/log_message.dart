import '../loggable/loggable.dart';
import '../loggable/loggable_multi_data.dart';
import '../loggable/loggable_named_data.dart';
import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogMessage implements LogBlock {
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;

  const LogMessage({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
  });

  @override
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  ) {
    final messageStr = switch (log.message) {
      '' => '',
      final message => theme.formatMessage(theme.formatValue(message)),
    };

    final errorStr = switch (log.error) {
      null => '',
      final error => theme.formatMessage(theme.formatValue(error.toString())),
    };

    final dataOnNewLine = theme.common.dataOnNewLine && !row.singleLine;
    final errorOnNewLine = theme.common.errorOnNewLine && !row.singleLine;

    var dataStr = '';
    var dataSectionName = '';

    if (log.hasData) {
      final data = log.data;
      switch (data) {
        case LoggableNamedData():
          dataSectionName =
              '${theme.sectionStyle(theme.formatSectionName(data.name))} ';
          dataStr = Loggable.objectToString(
            data.data,
            theme: theme,
            collectionMaxCount: data.collectionMaxCount,
            collectionMaxLength: data.collectionMaxLength,
            showCount: data.showCount ?? theme.common.showCount,
            showIndexes: data.showIndexes ?? theme.common.showIndexes,
            units: data.units,
          );

        case LoggableMultiData():
          dataSectionName = '';
          dataStr = data.data.entries.map((e) {
            final value = Loggable.objectToString(
              e.value,
              theme: theme,
              collectionMaxCount: data.collectionMaxCount,
              collectionMaxLength: data.collectionMaxLength,
              showCount: data.showCount ?? theme.common.showCount,
              showIndexes: data.showIndexes ?? theme.common.showIndexes,
              units: data.units,
            );
            return '${theme.sectionStyle(theme.formatSectionName(e.key))} $value';
          }).join(
            dataOnNewLine ? '\n' : theme.punctuationStyle(', '),
          );

        default:
          if (theme.common.dataSectionName case final name
              when name.isNotEmpty) {
            dataSectionName =
                '${theme.sectionStyle(theme.formatSectionName(name))} ';
          }
          dataStr = Loggable.objectToString(data, theme: theme);
      }
    }

    dataStr = '$dataSectionName$dataStr';

    return LogBox.fromText(
      log,
      theme,
      '$messageStr'
      '${messageStr.isEmpty || errorStr.isEmpty //
          ? errorStr : '${theme.styledColon}'
              '${errorOnNewLine ? '\n' : ' '}'
              '$errorStr'}'
      '${messageStr.isEmpty && errorStr.isEmpty || dataStr.isEmpty //
          ? dataStr : '${theme.styledColon}'
              '${dataOnNewLine ? '\n' : ' '}'
              '$dataStr'}',
      maxLines: row.maxLines,
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'message',
    );
  }
}
