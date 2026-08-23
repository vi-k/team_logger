// The minimum needed to configure a theme. The full style.dart barrel
// exports names that clash with Flutter (Color, Stack, State, Text and
// others). Styles is the table of ready-made styles (Styles.red,
// Styles.rgb050, Styles.bold): in 4.0.0 they stopped being top-level
// names, so this one class covers theming without a direct dependency on
// ansi_escape_codes.
export 'package:ansi_escape_codes/style.dart'
    show Color16, Color256, NoStyle, Style, Styles;
// `logger_builder` is the toolkit this package is built on, and only the part
// a team_logger user has to name is re-exported. The rest of it — the level
// constants `LogLevels` already covers, the `Custom*` supertypes of the final
// `Logger`/`Log`/`LevelLogger`, the `Lazy` family a caller never constructs,
// the `*Base` classes and the `*WithParam` axis this package does not use —
// stays where it belongs. Anyone building their own logger imports
// `package:logger_builder/logger_builder.dart` directly.
export 'package:logger_builder/logger_builder.dart'
    show
        AsyncPublisher,
        AsyncPublisherWithBuffer,
        Closable,
        CustomLogFormatter,
        CustomLogPublisher,
        Flushable,
        LogTransformer,
        MultiPublisher,
        TransformPublisher;

export 'src/loggable/loggable.dart';
export 'src/loggable/loggable_config.dart';
export 'src/loggable/loggable_json_config.dart';
export 'src/loggable/loggable_multi_data.dart';
export 'src/logger/log_levels.dart';
export 'src/logger/logger.dart';
export 'src/logger/trace_id.dart';
export 'src/preformatters/bb_code_formatter.dart';
export 'src/preformatters/control_code_formatter.dart';
export 'src/preformatters/custom_log_preformatter.dart';
export 'src/preformatters/log_pre_formatter.dart';
export 'src/preformatters/multi_log_pre_formatter.dart';
export 'src/preformatters/null_formatter.dart';
export 'src/printer/console_log_printer.dart';
// `src/printer/extensions.dart` is deliberately NOT exported. It holds the
// printer's own layout machinery — `applyConstraints` and `terminatedSlice`,
// which need a `Log` and a `LogTheme` to call — and one of the two extensions
// it declares is on `String`. Exporting it put that method on every String in
// every program that imports this package, where it collided with anyone
// else's `applyConstraints` on `String` as an ambiguous extension. The other
// extends `MeasuredLine`, which is not exported at all, so it could never be
// used. See docs/records/2026-08-24[5]-api-freeze-review.md.
export 'src/printer/constraints.dart';
export 'src/printer/log_block.dart';
export 'src/printer/log_custom_text.dart';
export 'src/printer/log_divider.dart';
export 'src/printer/log_level_name.dart';
export 'src/printer/log_message.dart';
export 'src/printer/log_num.dart';
export 'src/printer/log_path.dart';
export 'src/printer/log_row.dart';
export 'src/printer/log_stack_trace.dart';
export 'src/printer/log_tags.dart';
export 'src/printer/log_text_align.dart';
export 'src/printer/log_time.dart';
export 'src/printer/log_trace_id.dart';
export 'src/printer/log_vertical_align.dart';
export 'src/storage/log_storage.dart';
export 'src/theme/log_main_theme.dart';
