import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  test('team_logger re-exports the minimal ansi style set', () {
    // Compiling is the check itself: Style/NoStyle/Color16/Color256 and the
    // Styles table are reachable without depending on ansi_escape_codes
    // directly.
    const style = Style(foreground: Color256.rgb431);
    const noStyle = NoStyle();
    const color16 = Color16.red;
    const namedStyle = Styles.rgb050;

    expect(style.foreground, isNotNull);
    expect(noStyle, isA<Style>());
    expect(color16, isA<Color16>());
    expect(namedStyle.foreground, isNotNull);
  });

  test('LogBlock is the exported interface README names for row children', () {
    // README teaches `LogRow(children: [...], tail: [...])` as a list of
    // LogBlock; the name has to exist and the built-ins have to implement it.
    const blocks = <LogBlock>[
      LogNum(),
      LogLevelName.short(),
      LogTime.onlyTime(),
      LogPath(),
      LogTraceId(),
      LogMessage(),
      LogTags(),
    ];

    expect(blocks, everyElement(isA<LogBlock>()));
  });

  test('team_logger re-exports the curated part of logger_builder', () {
    // Compiling is the check: these nine names must be reachable through
    // team_logger.dart alone, without depending on logger_builder directly.
    // The rest of the toolkit is deliberately NOT re-exported — the level
    // constants LogLevels already covers, the Custom* supertypes of the
    // final Logger/Log/LevelLogger, the Lazy family, the *Base classes and
    // the *WithParam axis. Adding a name here is a decision, not a reflex:
    // whatever this package exports, it has to keep exporting.
    final publisher = CustomLogPublisher<Log>((_) {});
    final formatter = CustomLogFormatter<Log, String>(
      format: (log) => log.message,
      output: (_) {},
    );
    final multi = MultiPublisher<Log>([publisher]);
    final transform = TransformPublisher<Log>(publisher, transformer: (l) => l);
    final async = AsyncPublisher<Log>((_) {});
    final buffered = AsyncPublisherWithBuffer<Log>((_, __) {});

    expect(publisher, isA<CustomLogPublisher<Log>>());
    expect(formatter, isA<CustomLogPublisher<Log>>());
    expect(multi, isA<Flushable>());
    expect(multi, isA<Closable>());
    expect(transform, isA<CustomLogPublisher<Log>>());
    expect(async, isA<Flushable>());
    expect(buffered, isA<Closable>());
    // Named in the matcher rather than on a local: the point is that the
    // typedef itself is reachable through team_logger.dart.
    expect(_keepLog, isA<LogTransformer<Log>>());
  });

  test('team_logger exports the number formatter typedef', () {
    expect(_plainNumber, isA<LogNumberFormatter>());
    expect(_plainNumber(LogTheme.noColors, 42, 'ignored'), '42');
  });
}

String _plainNumber(LogTheme theme, num value, String pattern) =>
    value.toString();

Log? _keepLog(Log log) => log;
