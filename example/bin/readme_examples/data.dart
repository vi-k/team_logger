import 'package:example/readme_examples/default_log.dart';
import 'package:example/readme_examples/frames.dart';
import 'package:team_logger/team_logger.dart';

const _person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};

final frames = <String, LogFrame>{
  'data_1': _personData,
  'data_2': _deeplyNested,
  'data_3': _multiData,
  'data_4': _collections,
  'data_5': _map,
  'data_6': _iterableEfficientLength,
  'data_7': _enums,
  'data_8': _numbers,
  'data_9': _strings,
};

void main(List<String> args) => runFrames(frames, args);

/// Объект в сообщении и объект в `data`.
void _personData() {
  log.d('Person: $_person');
  log.d('Person', data: _person);
}

/// Вложенность и раскраска по глубине.
void _deeplyNested() {
  log.d(
    'deeply nested',
    data: {
      'deeply': {
        'nested': {'object': _person},
      },
    },
  );
}

/// Несколько именованных секций в одном логе.
void _multiData() {
  log.d(
    'Add new user',
    data: LoggableMultiData({
      'HEADERS': {'Content-Type': 'application/json'},
      'BODY': _person,
    }),
  );
}

/// Обрезка коллекций и показ длины.
void _collections() {
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
}

/// Обрезка `Map`: те же лимиты и тот же счётчик, что у списка.
void _map() {
  log.d(
    'Map',
    data: {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
    config: const LoggableConfig(collectionMaxCount: 3),
  );
}

/// Голый `Iterable`: по умолчанию один проход, с флагом — как у списка.
void _iterableEfficientLength() {
  log.d(
    'Iterable',
    data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
    config: const LoggableConfig(collectionMaxCount: 3),
  );

  log.d(
    'Iterable',
    data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
    config: const LoggableConfig(
      collectionMaxCount: 3,
      iterableEfficientLength: true,
    ),
  );
}

/// Enum: сокращённая и полная запись.
void _enums() {
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
}

/// Числа: шаблон исполняет форматтер темы.
void _numbers() {
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
}

/// Строки: в кавычках и без.
void _strings() {
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
