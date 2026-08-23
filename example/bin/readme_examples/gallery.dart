import 'package:example/readme_examples/default_log.dart';
import 'package:example/readme_examples/frames.dart';
import 'package:team_logger/team_logger.dart';

/// The frames behind the `screenshots:` gallery on pub.dev.
///
/// They are shot by the same pipeline as the README frames, but they are not
/// README frames: a picture in the gallery stands on its own, next to other
/// packages, with no prose around it to explain what it is comparing itself
/// to. So each one shows the package doing one thing, in one log, with
/// enough data on screen for the nesting and the depth colours to be visible
/// at a glance.
///
/// `quick_start_1` and `trace_1` complete the set and are reused as they are.
final frames = <String, LogFrame>{
  'gallery_1': _data,
  'gallery_2': _loggable,
};

void main(List<String> args) => runFrames(frames, args);

/// Structured data, nested, in one log.
void _data() {
  log.i(
    'Order placed',
    data: {
      'id': 4021,
      'customer': {'name': 'John Smith', 'vip': true},
      'shipTo': {'city': 'London', 'street': 'Baker St', 'building': 221},
      'items': ['espresso', 'croissant'],
      'total': 17.4,
    },
  );
}

/// An object that decides how it prints itself, nested objects included.
void _loggable() {
  log.i('Person', data: const Person());
}

final class Address with Loggable {
  final String city;
  final String street;
  final int building;

  const Address(this.city, this.street, this.building);

  @override
  void collectLoggableData(LoggableData data) => data
    ..prop('city', city)
    ..prop('street', street)
    ..prop('building', building);
}

final class Person with Loggable {
  const Person();

  @override
  void collectLoggableData(LoggableData data) => data
    ..prop('name', 'John Smith')
    ..prop('age', 42, units: 'y')
    ..prop('address', const Address('London', 'Baker Street', 221))
    ..prop('roles', const ['admin', 'editor']);
}
