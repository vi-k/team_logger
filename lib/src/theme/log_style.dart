part of 'log_main_theme.dart';

sealed class LogStyle {
  const factory LogStyle(ansi.Style style) = _LogStyle;

  const LogStyle._();
}

final class _LogStyle extends LogStyle {
  final ansi.Style style;

  const _LogStyle(this.style) : super._();
}

final class LogLazyStyle extends LogStyle {
  final ansi.Style Function(LogTheme theme) call;

  const LogLazyStyle(this.call) : super._();
}

final class LogNoStyle extends _LogStyle {
  const LogNoStyle() : super(const ansi.NoStyle());
}
