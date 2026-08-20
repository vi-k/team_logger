import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

Future<void> main() async {
  const person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};

  log.d('Person: $person');
  log.d('Person', data: person);

  print('----- Deeply nested objects -----');
  log.d(
    'deeply nested',
    data: {
      'deeply': {
        'nested': {'object': person},
      },
    },
  );

  print('----- Multi data -----');
  log.d(
    'Add new user',
    data: LoggableMultiData({
      'HEADERS': {'Content-Type': 'application/json'},
      'BODY': person,
    }),
  );

  print('----- Collections -----');

  log.d(
    'List',
    data: [1.2, 2.3, 3.4, 4.5, 5.6],
    config: const LoggableConfig(
      collectionMaxCount: 3,
      collectionShowCount: true,
      collectionShowIndexes: true,
    ),
  );

  log.d(
    'Set',
    data: {1.2, 2.3, 3.4, 4.5, 5.6},
    config: const LoggableConfig(collectionMaxCount: 3),
  );

  log.d(
    'Iterable',
    data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
    config: const LoggableConfig(collectionMaxCount: 3),
  );

  print('----- Formatting -----');

  log.d(
    'Enum',
    data: MyEnum.value1,
    config: LoggableConfig(enumDotShorthand: true),
  );
  log.d(
    'Enum',
    data: MyEnum.value2,
    config: LoggableConfig(enumDotShorthand: false),
  );

  log.d(
    'Float number with fixed precision',
    data: 1.23456789,
    config: const LoggableConfig(doubleFormat: '{:.4f}'),
  );
  log.d(
    'Integer number with grouping',
    data: 123456789,
    config: const LoggableConfig(intFormat: '{:,d}'),
  );

  log.d(
    'Integer number in hexadecimal',
    data: 123456789,
    config: const LoggableConfig(intFormat: '{:#x}'),
  );

  log.d(
    'String',
    data: 'abc',
    config: const LoggableConfig(stringInQuotes: true),
  );
  log.d(
    'String',
    data: 'abc',
    config: const LoggableConfig(stringInQuotes: false),
  );
}

enum MyEnum { value1, value2 }
