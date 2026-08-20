// A single request through the logger: namespaces, a trace id that follows
// the async flow, structured data, a redacted header and an error with a
// stack trace.
//
// Run it with `dart run example.dart` from this directory.
import 'package:team_logger/team_logger.dart';

// The application's logger: one console printer, one row — number, level,
// time, namespace, trace id, message. Tags go to the right edge.
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 100,
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

/// The HTTP layer's sublogger: its path is `app/api`, and every log it makes
/// carries the `http` tag. It follows [log] — changing the parent's level or
/// publisher reaches it too.
final api = log.createChild(name: 'api', tags: {'http'});

Future<void> main() async {
  // Redaction is global and per value: the rule is offered every value on
  // its way to the output, under the name it is printed with.
  Loggable.sanitizer =
      (ctx) => ctx.name == 'authorization' ? 'Bearer ***' : ctx.value;

  log.i('Application started', data: {'version': '1.2.3', 'env': 'demo'});

  // Everything logged inside picks up the trace id — at any depth and
  // across any await.
  await log.trace(TraceId.auto('req'), () async {
    api.d(
      'POST /addresses',
      data: LoggableMultiData({'HEADERS': _headers, 'BODY': _body}),
    );

    final address = await _fetchAddress();
    api.i('200 OK', data: address);

    try {
      await _fetchAddress(fail: true);
    } on Object catch (error, stackTrace) {
      api.e('request failed', error: error, stackTrace: stackTrace);
    }
  });

  log.i('Done');
}

const _headers = {
  'content-type': 'application/json',
  'authorization': 'Bearer eyJhbGciOiJub25lIn0.super-secret.signature',
  'accept-language': 'en',
};

const _body = {
  'point': {'lat': 12.345678, 'lon': 23.456789},
  'radius': 500,
};

/// Stands in for an HTTP call.
Future<Address> _fetchAddress({bool fail = false}) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  if (fail) {
    throw const FormatException('unexpected end of input');
  }

  return const Address(
    id: 1704,
    name: 'Cake Lab',
    street: 'Baker Street, 91',
    point: Point(12.349473, 23.439319),
    distance: 1240,
  );
}

/// A model that decides how it looks in a log.
///
/// Writing [collectLoggableData] is the whole job: the package renders the
/// properties, and every one of them passes the sanitizer.
final class Address with Loggable {
  final int id;
  final String name;
  final String street;
  final Point point;
  final int distance;

  const Address({
    required this.id,
    required this.name,
    required this.street,
    required this.point,
    required this.distance,
  });

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = '$Address'
    ..prop('id', id)
    ..prop('name', name)
    ..prop('street', street)
    ..prop('point', point)
    ..prop(
      'distance',
      distance,
      units: 'm',
      view: LoggableMultiView([
        LoggableView(distance, units: 'm'),
        LoggableView(distance / 1000, units: 'km'),
      ]),
    );
}

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = 'Point'
    ..showName = false
    ..round('lat', lat, precision: 5, showName: false)
    ..round('lon', lon, precision: 5, showName: false);
}
