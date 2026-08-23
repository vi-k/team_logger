import 'dart:convert';

import '../loggable/loggable.dart';
import '../loggable/loggable_config.dart';
import '../loggable/loggable_json_config.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';

/// How [Log.data] is written to a session file.
enum FileLogDataFormat {
  /// As a string produced by [Loggable.objectToString] (ANSI codes from the
  /// theme are preserved).
  text,

  /// As a JSON object produced by [Loggable.objectToJson].
  json,
}

/// Encodes [Log]s and session metadata as JSON Lines.
final class FileLogCodec {
  /// The key of the metadata line written as the first line of every chunk.
  static const String metaKey = ':meta';

  /// The version of the on-disk format, written to every meta line under
  /// `formatVersion`.
  ///
  /// A session file outlives the application that wrote it: an archive
  /// exported for diagnostics can be opened months later, by a tool built
  /// against a different version of this package. The version says which
  /// shape the reader is looking at, and it is the one thing that cannot be
  /// added after the fact — a file already written will never carry it.
  ///
  /// It is bumped when the shape of a line changes in a way a reader has to
  /// know about; adding a key is not such a change, since a reader that
  /// ignores unknown keys is unaffected. Like `sessionId` and `started`, it
  /// is written by the package and cannot be overridden through the `meta`
  /// argument of [encodeMeta].
  static const int formatVersion = 1;

  final FileLogDataFormat dataFormat;
  final LogMainTheme theme;
  final LoggableConfig config;
  final LoggableJsonConfig jsonConfig;

  FileLogCodec({
    this.dataFormat = FileLogDataFormat.text,
    LogMainTheme? theme,
    this.config = const LoggableConfig(),
    this.jsonConfig = const LoggableJsonConfig(),
  }) : theme = theme ?? LogMainTheme.noColors;

  /// Encodes [log] as a single JSON line (no trailing newline).
  String encode(Log log) {
    final levelTheme = theme[log.level];

    // `data` is the sanitizer's scope, so a rule may drop the whole root.
    // The drop is signalled out of band — an empty rendering is legal on
    // its own — and it removes the key entirely, the same way the console
    // printer removes the data block instead of printing a bare colon.
    Object? data;
    var hasData = log.hasData;
    if (hasData) {
      switch (dataFormat) {
        case FileLogDataFormat.text:
          final rendered = Loggable.renderRoot(
            log.data,
            theme: levelTheme,
            config: config,
          );
          data = rendered.text;
          hasData = !rendered.dropped;
        case FileLogDataFormat.json:
          final rendered = Loggable.renderRootJson(
            log.data,
            config: jsonConfig,
          );
          data = rendered.json;
          hasData = !rendered.dropped;
      }
    }

    return jsonEncode(<String, Object?>{
      'num': log.num,
      'level': log.level,
      'levelName': log.levelName,
      'time': log.time.toUtc().toIso8601String(),
      if (log.path.isNotEmpty) 'path': log.path,
      if (log.traceIds.isNotEmpty)
        'traceIds': [for (final id in log.traceIds) id.toString()],
      'message': levelTheme.formatMessage(
        levelTheme.formatValue(
          log.message,
          escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
        ),
        escapeAnsiCodes: false,
      ),
      if (log.tags.isNotEmpty) 'tags': [...log.tags],
      if (hasData) 'data': data,
      // The error and the stack trace are outside the sanitizer's
      // documented scope (values inside `data` only): both are rendered
      // with the root offer suppressed, so a `depth == 0` rule cannot
      // erase or rewrite them.
      if (log.error case final error?)
        'error': Loggable.renderOutsideSanitizerScope(error.toString),
      if (log.stackTrace case final stackTrace?)
        'stackTrace': Loggable.renderOutsideSanitizerScope(
          stackTrace.toString,
        ),
    });
  }

  /// Encodes the session metadata line (no trailing newline).
  ///
  /// The package-provided `sessionId` and `started` keys always win over
  /// the same keys in [meta]. Never throws: user meta values are converted
  /// to JSON-safe representations via [Loggable.objectToJson]; if that is
  /// impossible, the line degrades to the package-provided keys only.
  String encodeMeta({
    required String sessionId,
    required DateTime started,
    Map<String, Object?>? meta,
  }) {
    final auto = <String, Object?>{
      'formatVersion': formatVersion,
      'sessionId': sessionId,
      'started': started.toUtc().toIso8601String(),
    };

    var userMeta = const <String, Object?>{};
    if (meta != null) {
      try {
        final converted = Loggable.objectToJson(meta);
        if (converted is Map<String, Object?>) {
          userMeta = converted;
        }
      } on Object {
        // Invalid metadata must not block writing logs.
      }
    }

    try {
      return jsonEncode(<String, Object?>{
        metaKey: {...userMeta, ...auto},
      });
    } on Object {
      return jsonEncode(<String, Object?>{metaKey: auto});
    }
  }
}
