import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:team_logger/team_logger.dart';

part 'data.freezed.dart';

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 100,
        children: [
          LogSequenceNum(),
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

Future<void> main() async {
  // const person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};

  // log.d('Person: $person');
  // log.d('Person', data: person);

  // print('----- Deeply nested objects -----');
  // log.d(
  //   'deeply nested',
  //   data: {
  //     'deeply': {
  //       'nested': {'object': person},
  //     },
  //   },
  // );

  // print('----- Multi data -----');
  // log.d(
  //   'Add new user',
  //   data: LoggableMultiData({
  //     'HEADERS': {'Content-Type': 'application/json'},
  //     'BODY': person,
  //   }),
  // );

  // print('----- Collections -----');

  log.d(
    'List',
    data: [1.2, 2.3, 3.4, 4.5, 5.6],
    config: const LoggableConfig(
      collectionMaxLength: 3,
      collectionShowLength: true,
      collectionShowIndexes: true,
    ),
  );

  log.d(
    'Set',
    data: {1.2, 2.3, 3.4, 4.5, 5.6},
    config: const LoggableConfig(collectionMaxLength: 3),
  );

  log.d(
    'Iterable',
    data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
    config: const LoggableConfig(collectionMaxLength: 3),
  );
}

final class Person1 {
  final String name;
  final int age;

  const Person1(this.name, this.age);

  @override
  String toString() => 'Person1(name: $name, age: $age)';
}

final class Person2 extends Equatable {
  final String name;
  final int age;

  const Person2(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

@freezed
abstract class Person3 with _$Person3 {
  const factory Person3(String name, int age) = _Person3;
}

final class Person4 with Loggable {
  final String name;
  final int age;

  const Person4(this.name, this.age);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('age', age);
  }
}
