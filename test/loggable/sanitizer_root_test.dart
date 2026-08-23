import 'dart:async';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Захватывает то, что напечатал `print`.
String _captured(void Function() body) {
  final lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) => lines.add(line),
    ),
  );

  return lines.join('\n');
}

/// Данные, которые легитимно рендерятся в пустую строку.
LoggableData _emptyRendering() => Loggable.builder(
      Object(),
      showName: false,
      showBrackets: false,
    );

/// Регрессии по задаче D кросс-ревью 0.6.1: единая политика `units` у
/// корневой замены (D1), явный сигнал «отброшено» вместо пустой строки
/// (D2), multi-data со всеми выброшенными секциями (D3) и корневое
/// предложение на `toString()` (D4).
void main() {
  group('sanitizer root — units are not inherited by a replacement', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a multi-data root replacement drops the container units', () {
      // `units` — утверждение о величине, а замена ею не является: то же
      // правило, что уже действует у свойства (`LoggableConfig
      // .withoutUnits`), теперь действует и в корне. Все четыре
      // рендерера multi-data обязаны совпасть.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(units: 'kg'),
      );

      expect(data.toString(), '12', reason: 'LoggableMultiData.toString');
      expect(
        Loggable.objectToString(data),
        '12',
        reason: 'Loggable.objectToString',
      );
      expect(Loggable.objectToJson(data), 12, reason: 'Loggable.objectToJson');
      expect(_printData(data), 'login: 12', reason: 'ConsoleLogPrinter');
    });

    test('the rest of the container config still applies to a replacement', () {
      // Наследование конфига контейнера снимается только с `units`:
      // `collectionMaxCount` и прочие поля описывают не величину, а
      // способ печати, и остаются в силе.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(collectionMaxCount: 1, units: 'kg'),
      );

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
    });

    test('units survive when the rule does not touch the root', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final data = LoggableMultiData(
        {'s': 12},
        config: const LoggableConfig(units: 'kg'),
      );

      expect(Loggable.objectToString(data), 's: 12kg');
      expect(Loggable.objectToJson(data), {
        ':k': 'multi',
        's': {':v': 12, ':u': 'kg'},
      });
    });

    test('a wrapper root replacement drops the wrapper units too', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      final data = Loggable.from(1, config: const LoggableConfig(units: 'kg'));
      expect(
        Loggable.objectToString(data),
        '12',
        reason: 'Loggable.objectToString',
      );
      expect(Loggable.objectToJson(data), 12, reason: 'Loggable.objectToJson');
      expect(_printData(data), 'login: 12', reason: 'ConsoleLogPrinter');
    });

    test('an ambient units config is not applied to a replacement either', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      expect(
        Loggable.objectToString(1, config: const LoggableConfig(units: 'kg')),
        '12',
      );
    });
  });

  group('sanitizer root — a replacement inherits the container config', () {
    tearDown(() => Loggable.sanitizer = null);

    // Замена встаёт на место контейнера, поэтому печатается его настройками.
    // `units` при этом снимаются, остальное — способ печати — наследуется.
    // Раньше это умели только `LoggableMultiData` и `LoggableWrapper`:
    // билдеры держат свой config приватным полем, и общий код его не видел.
    const config = LoggableConfig(collectionMaxCount: 1, units: 'kg');

    setUp(() {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;
    });

    test('builder applies collectionMaxCount to a root replacement', () {
      final data = Loggable.builder(Object(), config: config)
        ..prop('s', 'topsecret');

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('mapBuilder applies collectionMaxCount to a root replacement', () {
      final data = Loggable.mapBuilder(config: config)..prop('s', 'topsecret');

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('multi-data does the same in JSON, not only in the string', () {
      final data = LoggableMultiData({'s': 'topsecret'}, config: config);

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('a wrapper keeps doing it by unwrapping before the root offer', () {
      final data = LoggableWrapper('topsecret', config: config);

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('a builder without its own config still takes the outer one', () {
      final data = Loggable.builder(Object())..prop('s', 'topsecret');

      expect(
        Loggable.objectToString(data, config: config),
        '[₌₃ ₀:1, …]',
      );
    });
  });

  group('sanitizer root — an empty rendering is not a drop', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a replacement rendering empty keeps the colon on the console', () {
      // До фикса дроп сообщался пустой строкой, и замена, легитимно
      // отрендерившаяся в пустоту, читалась как дроп: печаталось `login`
      // вместо `login: `.
      Loggable.sanitizer =
          (ctx) => ctx.depth == 0 ? _emptyRendering() : ctx.value;

      expect(_printData({'s': 'topsecret'}), 'login:');
      expect(_printData(LoggableMultiData({'s': 'topsecret'})), 'login:');
    });

    test('a dropped root still removes the data block', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_printData({'s': 'topsecret'}), 'login');
      expect(_printData(LoggableMultiData({'s': 'topsecret'})), 'login');
    });
  });

  group('sanitizer root — multi-data with every section dropped', () {
    tearDown(() => Loggable.sanitizer = null);

    test('leaves no data block at all', () {
      // Висящая метка `login: ` без содержимого — шум: блок данных
      // пропадает, если текст пуст И хотя бы одна запись отброшена.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? ctx.value : Sanitize.drop;

      expect(
        _printData(LoggableMultiData({'a': 1, 'b': 2})),
        'login',
      );
    });

    test('an empty multi-data keeps its colon with a rule armed', () {
      // Пустая сама по себе multi-data — законный пустой рендер, не дроп
      // (закреплено в B6).
      Loggable.sanitizer = (ctx) => ctx.value;

      expect(_printData(LoggableMultiData({})), 'login:');
    });

    test('an empty multi-data keeps its colon without a rule', () {
      expect(_printData(LoggableMultiData({})), 'login:');
    });

    test('surviving sections are still printed when only some are dropped', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      expect(
        _printData(LoggableMultiData({'req': 'ok', 'password': 'hunter2'})),
        'login: req: "ok"',
      );
    });
  });

  group('sanitizer root — toString offers the root', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a root rule reaches string interpolation of a Loggable', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      final user = _User('ann', 'topsecret');
      expect('$user', '"<ROOT>"');
      expect(Loggable.objectToString(user), '"<ROOT>"');
    });

    test('a root rule reaches LoggableData.toString', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      final data = Loggable.builder(Object())..prop('s', 'topsecret');
      expect('$data', '"<ROOT>"');
      expect(Loggable.objectToString(data), '"<ROOT>"');
    });

    test('a root drop renders an empty string on interpolation', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect('${_User('ann', 'topsecret')}', isEmpty);
      expect(
        '${Loggable.builder(Object())..prop('s', 'topsecret')}',
        isEmpty,
      );
    });

    test('print() goes through the same root offer', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      expect(_captured(() => print(_User('ann', 'topsecret'))), '"<ROOT>"');
    });

    test('props are still sanitized on the toString path', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final user = _User('ann', 'hunter2');
      expect('$user', '_User(name: "ann", password: "***")');
      expect(
        '${Loggable.mapBuilder()..prop('password', 'hunter2')}',
        // mapBuilder — структура свойств, а не коллекция: лимиты к ней не
        // применяются, счётчика записей у неё нет.
        '{password: "***"}',
      );
    });

    test('the root is offered exactly once on every path', () {
      var roots = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.depth == 0) roots++;

        return ctx.value;
      };

      final user = _User('ann', 'hunter2');
      final data = Loggable.builder(Object())..prop('s', 'x');

      Loggable.objectToString(user);
      expect(roots, 1, reason: 'objectToString');

      roots = 0;
      Loggable.objectToJson(user);
      expect(roots, 1, reason: 'objectToJson');

      roots = 0;
      user.toString();
      expect(roots, 1, reason: 'Loggable.toString via interpolation');

      roots = 0;
      _captured(() => print(user));
      expect(roots, 1, reason: 'print(obj)');

      roots = 0;
      data.toString();
      expect(roots, 1, reason: 'LoggableData.toString');

      roots = 0;
      Loggable.objectToString(data);
      expect(roots, 1, reason: 'objectToString of a LoggableData');

      roots = 0;
      Loggable.objectToJson(data);
      expect(roots, 1, reason: 'objectToJson of a LoggableData');
    });

    test('a nested Loggable is not offered a second time as a root', () {
      // `toString()` вложенного объекта зовётся изнутри обхода — там
      // значение уже предложено своей позицией.
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      Loggable.objectToString({'u': _User('ann', 'hunter2')});

      expect(seen, ['@0', 'u@1', 'u.name@2', 'u.password@2']);
    });

    test('a Loggable map key still offers its props once, not a root', () {
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      final map = <Object?, Object?>{_Account('DE89'): 'primary'};

      Loggable.objectToString(map);
      final text = [...seen];
      seen.clear();

      Loggable.objectToJson(map);

      expect(text, ['@0', 'iban@1', '_Account(iban: "DE89")@1']);
      expect(seen, text);
    });

    test('a Loggable reached through a plain toString is not a second root',
        () {
      // Обходчик рисует незнакомый тип его собственным `toString()`, а
      // тот вправе интерполировать [Loggable]. Без заглушки на весь
      // рендер корня стек в этот момент был бы пуст — и вложенный
      // объект сделал бы ВТОРОЙ корневой офер (`@0`), затерев в правилах
      // по depth == 0 настоящий корень.
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      final envelope = _Envelope(_Account('DE89'));

      Loggable.objectToString(envelope);
      expect(seen, ['@0', 'iban@1'], reason: 'objectToString');

      seen.clear();
      Loggable.objectToJson(envelope);
      expect(seen, ['@0', 'iban@1'], reason: 'objectToJson');
    });

    test('a rule rendering the value it was handed does not recurse', () {
      // Нарушение контракта (правилу рендерить нельзя), но повесить
      // процесс оно не должно: заглушка держится и на время вызова
      // правила, и на весь рендер корня.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '${ctx.value}' : ctx.value;

      expect('${_User('ann', 'hunter2')}', contains('_User'));
    });

    test('without a rule toString is unchanged', () {
      expect(
        _User('ann', 'hunter2').toString(),
        '_User(name: "ann", password: "hunter2")',
      );
      expect(
        (Loggable.builder(Object(), name: 'D')..prop('s', 'x')).toString(),
        'D(s: "x")',
      );
    });
  });
}

/// Прогоняет лог через настоящий [ConsoleLogPrinter] в одну строку.
String _printData(Object? data) {
  final lines = <String>[];
  Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      rows: const [
        LogRow.singleLine(children: [LogMessage()]),
      ],
      output: lines.add,
    )
    ..i('login', data: data);

  return lines.join('\n').trimRight();
}

final class _User with Loggable {
  final String name;
  final String password;

  _User(this.name, this.password);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('password', password);
  }
}

final class _Account with Loggable {
  final String iban;

  _Account(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);
}

/// Тип, о котором обходчик ничего не знает: он рисуется собственным
/// `toString()`, а тот заходит в [Loggable].
final class _Envelope {
  final _Account inner;

  _Envelope(this.inner);

  @override
  String toString() => 'Envelope($inner)';
}
