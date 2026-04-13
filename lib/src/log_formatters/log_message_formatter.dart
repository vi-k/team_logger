import '../loggable/loggable.dart';
import '../loggable/loggable_multi_data.dart';
import '../loggable/loggable_named_data.dart';
import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogMessageFormatter implements LogFormatter {
  const factory LogMessageFormatter({
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
  }) = _LogMessageFormatter;
}

final class _LogMessageFormatter implements LogMessageFormatter {
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;

  const _LogMessageFormatter({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final messageStr = switch (log.message) {
      '' => '',
      final message => theme.formatMessage(theme.formatValue(message)),
    };

    final errorStr = switch (log.error) {
      null => '',
      final error => theme.formatMessage(theme.formatValue(error.toString())),
    };

    var dataStr = '';
    if (log.data case final data?) {
      var dataSectionName = '';

      switch (data) {
        case LoggableNamedData():
          dataSectionName =
              '${theme.dataSectionStyle(theme.formatSectionName(data.name))} ';
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
            return '${theme.dataSectionStyle(theme.formatSectionName(e.key))} $value';
          }).join(
            theme.common.dataOnNewLine ? '\n' : theme.punctuationStyle(', '),
          );

        default:
          if (theme.common.dataSectionName case final name
              when name.isNotEmpty) {
            dataSectionName =
                '${theme.dataSectionStyle(theme.formatSectionName(name))} ';
          }
          dataStr = Loggable.objectToString(data, theme: theme);
      }

      dataStr = '$dataSectionName$dataStr';
    }

    return LogFormatterBox.fromText(
      log,
      theme,
      '$messageStr'
      '${messageStr.isEmpty || errorStr.isEmpty //
          ? errorStr : '${theme.styledColon}'
              '${theme.common.errorOnNewLine ? '\n' : ' '}'
              '$errorStr'}'
      '${messageStr.isEmpty && errorStr.isEmpty || dataStr.isEmpty //
          ? dataStr : '${theme.styledColon}'
              '${theme.common.dataOnNewLine ? '\n' : ' '}'
              '$dataStr'}',
      maxLines: theme.common.maxLines,
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'message',
    );
  }
}
