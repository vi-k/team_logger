/// The full `team_logger` API plus file-based log storage (`dart:io`).
///
/// Use this import instead of `package:team_logger/team_logger.dart` on
/// platforms with file system access (VM, Flutter mobile/desktop). The core
/// `team_logger.dart` library stays platform-independent.
library;

export 'src/file_storage/file_log_codec.dart';
export 'src/file_storage/file_log_sessions.dart'
    show FileLogSession, FileLogSessions;
export 'src/file_storage/file_log_storage.dart';
export 'team_logger.dart';
