part of 'log_main_theme.dart';

sealed class LogLazyStyle {
  const factory LogLazyStyle(ansi.Style Function(LogTheme theme) fn) =
      _LogLazyStyle;

  const factory LogLazyStyle.resolved(ansi.Style style) = _LogResolvedStyle;

  const LogLazyStyle._();
}

final class _LogResolvedStyle extends LogLazyStyle {
  final ansi.Style style;

  const _LogResolvedStyle(this.style) : super._();
}

final class _LogLazyStyle extends LogLazyStyle {
  final ansi.Style Function(LogTheme theme) call;

  const _LogLazyStyle(this.call) : super._();
}
