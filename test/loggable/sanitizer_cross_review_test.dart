import 'package:ansi_escape_codes/extensions.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Регрессии кросс-ревью 0.6.1 (Codex + адверсариальный ревьюер).
///
/// Каждая группа пинит одну находку: двойной рендер ключа [Map] (B1),
/// его безусловность (B2), санитайз отсечённого лимитом элемента (B4),
/// поведение [Prop] при `Sanitize.drop` (B9.2). Отдельная группа пинит
/// то, что README §10 и dartdoc `Loggable.sanitizer` обещают про
/// содержимое объекта-ключа: где оно предлагается правилу, под каким
/// путём и где НЕ предлагается (утечка в JSON).
void main() {
  group('cross-review — a map key is rendered exactly once', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a Loggable key offers its props once, at one path in both outputs',
        () {
      // Ключ рендерился дважды: черновым `entry.key.toString()` (для
      // пути) и ещё раз в вывод — с расходящимися путями, из-за чего
      // правило по пути маскировало черновик и пропускало напечатанное.
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
      final json = [...seen];

      // Свойства ключа предлагаются под путём самого ключа (ключ — не
      // сегмент пути, см. README §10), значение записи — под ключом.
      expect(text, ['@0', 'iban@1', '_Account(iban: "DE89")@1']);
      expect(json, text);
    });

    test('a path rule masks the printed key in both outputs', () {
      Loggable.sanitizer = (ctx) => ctx.path == 'iban' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        _Account('DE89370400440532013000'): 'primary',
      };

      expect(
        Loggable.objectToString(map),
        '{₌₁ _Account(iban: "<masked>"): "primary"}',
      );
      expect(
        Loggable.objectToJson(map),
        {'_Account(iban: "<masked>")': 'primary'},
      );
    });

    test('a non-String key is rendered exactly once without a sanitizer', () {
      // «Одна проверка на null на значение, больше ничего»: без правила
      // ключ обязан рендериться ровно так же, как до 0.6.0.
      final key = _CountingKey();

      Loggable.objectToString(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToString');

      key.calls = 0;
      Loggable.objectToJson(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToJson');
    });

    test('a non-String key is rendered exactly once with a rule armed', () {
      Loggable.sanitizer = (ctx) => ctx.value;
      final key = _CountingKey();

      Loggable.objectToString(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToString');

      key.calls = 0;
      Loggable.objectToJson(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToJson');
    });

    test('a Loggable key with a throwing toString still renders as text', () {
      // До 0.6.0 строковый путь рисовал нестроковые ключи через
      // objectToString, поэтому toString() такого ключа не звался вовсе.
      final map = <Object?, Object?>{_ThrowingKey('DE89'): 'primary'};

      expect(
        Loggable.objectToString(map),
        '{₌₁ _ThrowingKey(iban: "DE89"): "primary"}',
      );
    });

    test('the same key still throws in JSON, as it did before 0.6.0', () {
      // Асимметрия двух путей, а не недосмотр: JSON рисует ключ через
      // `key.toString()` и звал его и в 0.5.2. Пин, чтобы «строковый путь
      // toString не зовёт» не прочиталось как «не зовёт нигде».
      final map = <Object?, Object?>{_ThrowingKey('DE89'): 'primary'};

      expect(() => Loggable.objectToJson(map), throwsStateError);

      Loggable.sanitizer = (ctx) => ctx.value;
      expect(() => Loggable.objectToJson(map), throwsStateError);
    });

    test('the key handed to the rule carries no escape codes', () {
      final names = <String?>[];
      Loggable.sanitizer = (ctx) {
        names.add(ctx.name);

        return ctx.value;
      };

      // Тема со стилями: сам напечатанный ключ раскрашен, но имя и путь —
      // это данные для правила, а не вывод.
      final theme = LogMainTheme(info: LogThemeData.gray10).info;
      final out = Loggable.objectToString(
        <Object?, Object?>{_Account('DE89'): 'primary'},
        theme: theme,
      );

      expect(out.ansiHasEscapeCodes, isTrue);
      expect(names.last, '_Account(iban: "DE89")');
    });
  });

  group('cross-review — what a key object exposes to the rule', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a secret inside a non-Loggable key survives into JSON', () {
      // Документированное поведение, не баг «на будущее»: строковый путь
      // рисует любой ключ обходчиком, а JSON — через `key.toString()`,
      // поэтому внутрь обычного контейнера-ключа правило в JSON не
      // заходит. Если этот вывод когда-нибудь закроют, тест упадёт — и
      // вместе с ним придётся править README §10 и dartdoc [sanitizer].
      Loggable.sanitizer = (ctx) => ctx.name == 'pw' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        {'pw': 'hunter2'}: 'primary',
      };

      expect(
        Loggable.objectToString(map),
        '{₌₁ {₌₁ pw: "<masked>"}: "primary"}',
      );
      expect(Loggable.objectToJson(map), {'{pw: hunter2}': 'primary'});
    });

    test('a Loggable key is offered in both outputs', () {
      // Обратная сторона той же асимметрии: `toString` [Loggable]-ключа
      // заходит в обходчики, поэтому в JSON он всё-таки санитайзится.
      Loggable.sanitizer = (ctx) => ctx.name == 'iban' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{_Account('DE89'): 'primary'};

      expect(
        Loggable.objectToString(map),
        '{₌₁ _Account(iban: "<masked>"): "primary"}',
      );
      expect(
        Loggable.objectToJson(map),
        {'_Account(iban: "<masked>")': 'primary'},
      );
    });

    test('the contents of a key carry the container path, not the entry', () {
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx.path);

        return ctx.value;
      };

      Loggable.objectToString(<Object?, Object?>{
        'acc': <Object?, Object?>{_Account('DE89'): 'x'},
      });

      // Свойство ключа — `acc.iban`, то есть путь КОНТЕЙНЕРА `acc`, а не
      // путь записи `acc._Account(iban: "DE89")`.
      expect(seen, ['', 'acc', 'acc.iban', 'acc._Account(iban: "DE89")']);
    });

    test('ctx.name of a non-String key is the key as that output renders it',
        () {
      // Следствие правильного исправления (имя = ключ в том виде, в
      // каком он напечатан, посчитанный один раз и переиспользованный), а
      // не баг: строковый путь берёт имя из objectToString, JSON — из
      // key.toString(). Формы разные, и строковая зависит от темы.
      final names = <String>[];
      Loggable.sanitizer = (ctx) {
        if (ctx.name case final name?) names.add(name);

        return ctx.value;
      };

      final listKey = <Object?, Object?>{
        [1, 2]: 'hunter2',
      };
      final enumKey = <Object?, Object?>{_Role.admin: 'hunter2'};

      Loggable.objectToJson(listKey);
      expect(names, ['[1, 2]'], reason: 'objectToJson');

      names.clear();
      Loggable.objectToString(listKey);
      expect(names, ['[₌₂ ₀:1, ₁:2]'], reason: 'objectToString');

      names.clear();
      Loggable.objectToJson(enumKey);
      expect(names, ['_Role.admin'], reason: 'objectToJson, enum key');

      names.clear();
      Loggable.objectToString(enumKey);
      expect(names, ['.admin'], reason: 'objectToString, enum key');
    });

    test('a name rule written for one output misses the other', () {
      // Поэтому README и dartdoc велят редактировать такие записи по
      // значению или выбрасывать целиком, а не правилом по тексту ключа.
      Loggable.sanitizer =
          (ctx) => ctx.name == '[1, 2]' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        [1, 2]: 'hunter2',
      };

      expect(Loggable.objectToJson(map), {'[1, 2]': '<masked>'});
      expect(Loggable.objectToString(map), contains('hunter2'));
    });

    test('dropping the entry is what keeps a key secret out of JSON', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == '{pw: hunter2}' ? Sanitize.drop : ctx.value;

      expect(
        Loggable.objectToJson(<Object?, Object?>{
          {'pw': 'hunter2'}: 'primary',
        }),
        <String, Object?>{},
      );
    });
  });

  group('cross-review — collectionMaxCount does not render the cut tail', () {
    tearDown(() => Loggable.sanitizer = null);

    test('with maxCount 1 the last element is not offered to the rule', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2, 3],
          config: const LoggableConfig(collectionMaxCount: 1),
        ),
        '[₌₃ ₀:1, …]',
      );
      expect(offered, ['=[1, 2, 3]', '[0]=1']);
    });

    test('with maxCount 1 and two elements the tail is not offered either', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2],
          config: const LoggableConfig(collectionMaxCount: 1),
        ),
        '[₌₂ ₀:1, …]',
      );
      expect(offered, ['=[1, 2]', '[0]=1']);
    });

    test('the surviving last element is still offered, in output order', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2, 3, 4],
          config: const LoggableConfig(collectionMaxCount: 3),
        ),
        '[₌₄ ₀:1, ₁:2, …, ₃:4]',
      );
      expect(offered, ['=[1, 2, 3, 4]', '[0]=1', '[3]=4', '[1]=2']);
    });
  });

  group('cross-review — LoggableData.toJson without a sanitizer', () {
    test('keeps the map shape', () {
      expect(
        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..prop('a', 1)
            ..prop('b', 2),
        ),
        {
          ':c': 'D',
          ':p': {'a': 1, 'b': 2},
        },
      );
    });

    test('keeps the list shape when an unnamed prop is present', () {
      expect(
        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..prop('a', 1)
            ..prop('b', 2, showName: false),
        ),
        {
          ':c': 'D',
          ':p': [
            {'a': 1},
            2,
          ],
        },
      );
    });
  });

  group('cross-review — a Prop rendered directly on drop', () {
    tearDown(() => Loggable.sanitizer = null);

    test('prints the drop marker, having no container to remove it from', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final props = _User('ann', 'hunter2').logClassInfo().props;

      expect(
        props.map((p) => p.toLogString()).toList(),
        ['name: "ann"', 'password: <dropped>'],
      );
      expect(
        Map.fromEntries(props.map((p) => p.toMapEntry())),
        {
          'name': 'ann',
          'password': {':view': '<dropped>'},
        },
      );
    });

    test('rendering through LoggableData removes the prop entirely', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      expect(
        Loggable.objectToString(_User('ann', 'hunter2')),
        '_User(name: "ann")',
      );
    });
  });
}

final class _Account with Loggable {
  final String iban;

  _Account(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);
}

final class _ThrowingKey with Loggable {
  final String iban;

  _ThrowingKey(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);

  @override
  String toString() => throw StateError('toString must not be called');
}

enum _Role { admin }

final class _CountingKey {
  int calls = 0;

  @override
  String toString() {
    calls++;

    return 'key';
  }
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
