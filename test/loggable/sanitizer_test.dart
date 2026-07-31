import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Loggable.sanitizer — root', () {
    tearDown(() => Loggable.sanitizer = null);

    test('is not applied when null', () {
      expect(Loggable.objectToString('secret'), '"secret"');
      expect(Loggable.objectToJson('secret'), 'secret');
    });

    test('replaces the root value in both outputs', () {
      Loggable.sanitizer = (ctx) => '***';

      expect(Loggable.objectToString('secret'), '"***"');
      expect(Loggable.objectToJson('secret'), '***');
    });

    test('sees the root as an unnamed value at depth 0', () {
      final seen = <SanitizeContext>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx);

        return ctx.value;
      };

      Loggable.objectToString('secret');

      expect(seen.single.name, isNull);
      expect(seen.single.value, 'secret');
      expect(seen.single.depth, 0);
      expect(seen.single.path, isEmpty);
    });

    test('drop at the root renders empty', () {
      Loggable.sanitizer = (ctx) => Sanitize.drop;

      expect(Loggable.objectToString('secret'), isEmpty);
      expect(Loggable.objectToJson('secret'), isNull);
    });

    test('is applied exactly once per rendered value', () {
      // Правило ведёт себя по-разному при повторном применении: первый
      // вызов заменяет значение, любой следующий — убрал бы его. Тест
      // остаётся осмысленным только если санитайзер не сработает дважды
      // на одно и то же (в т.ч. на замену корня).
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return calls == 1 ? '***' : Sanitize.drop;
      };

      expect(Loggable.objectToString('secret'), '"***"');
      expect(calls, 1);
    });
  });

  group('Loggable.sanitizer — maps', () {
    tearDown(() => Loggable.sanitizer = null);

    test('replaces a value by key in both outputs', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      const data = {'user': 'ann', 'password': 'hunter2'};
      expect(Loggable.objectToString(data), '{user: "ann", password: "***"}');
      expect(Loggable.objectToJson(data), {'user': 'ann', 'password': '***'});
    });

    test('drop removes the entry with its separator', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      const data = {'a': 1, 'password': 'hunter2', 'c': 3};
      expect(Loggable.objectToString(data), '{a: 1, c: 3}');
      expect(Loggable.objectToJson(data), {'a': 1, 'c': 3});
    });

    test('reports name, depth and path for nested maps', () {
      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({
        'user': {
          'card': {'pan': '4111'},
        },
      });

      expect(seen, {
        '|null': 0,
        'user|user': 1,
        'user.card|card': 2,
        'user.card.pan|pan': 3,
      });
    });

    test('replacing a map stops the walk inside it', () {
      final names = <String?>[];
      Loggable.sanitizer = (ctx) {
        names.add(ctx.name);

        return ctx.name == 'card' ? '<redacted>' : ctx.value;
      };

      expect(
        Loggable.objectToString({
          'card': {'pan': '4111', 'cvv': '123'},
        }),
        '{card: "<redacted>"}',
      );
      expect(names, [null, 'card']);
    });

    test('LoggableMultiData entries are sanitized by key', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final data = LoggableMultiData({'req': 'ok', 'password': 'hunter2'});
      expect(Loggable.objectToString(data), 'req: "ok"');
      expect(Loggable.objectToJson(data), {':k': 'multi', 'req': 'ok'});
    });

    test(
      'depth and path of a replaced root children skip the '
      'placeholder segment',
      () {
        final seen = <String, int>{};
        Loggable.sanitizer = (ctx) {
          if (ctx.name == null) return {'replacement': 'x'};

          seen['${ctx.path}|${ctx.name}'] = ctx.depth;

          return ctx.value;
        };

        Loggable.objectToString({'original': 'y'});

        expect(seen, {'replacement|replacement': 1});
      },
    );

    test(
      'Sanitize.drop as ordinary map data is not swallowed when unset',
      () {
        // Loggable.sanitizer остаётся null: Sanitize.drop — публичный API,
        // и приложение вправе хранить его как обычные данные. Проверка
        // на drop не должна срабатывать без установленного санитайзера.
        final data = {'a': 1, 'b': Sanitize.drop, 'c': 3};
        final droppedText = Loggable.objectToString(Sanitize.drop);
        expect(
          Loggable.objectToString(data),
          '{a: 1, b: $droppedText, c: 3}',
        );

        final droppedJson = Loggable.objectToJson(Sanitize.drop);
        expect(
          Loggable.objectToJson(data),
          {'a': 1, 'b': droppedJson, 'c': 3},
        );
      },
    );

    test(
      'Sanitize.drop as ordinary multi-data value is not swallowed '
      'when unset',
      () {
        final data = LoggableMultiData({'req': 'ok', 'flag': Sanitize.drop});
        final droppedText = Loggable.objectToString(Sanitize.drop);
        expect(
          Loggable.objectToString(data),
          'req: "ok", flag: $droppedText',
        );

        final droppedJson = Loggable.objectToJson(Sanitize.drop);
        expect(
          Loggable.objectToJson(data),
          {':k': 'multi', 'req': 'ok', 'flag': droppedJson},
        );
      },
    );
  });

  group('Loggable.sanitizer — collections', () {
    tearDown(() => Loggable.sanitizer = null);

    test('elements are unnamed and indexed in the path', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add('${ctx.path}|${ctx.name}');

        return ctx.value;
      };

      Loggable.objectToString({
        'items': [
          {'pan': '4111'},
        ],
      });

      expect(paths, [
        '|null',
        'items|items',
        'items[0]|null',
        'items[0].pan|pan',
      ]);
    });

    test('replaces an element value', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'secret' ? '***' : ctx.value;

      expect(
        Loggable.objectToString(['a', 'secret']),
        contains('"***"'),
      );
      expect(
        Loggable.objectToString(['a', 'secret']),
        isNot(contains('secret')),
      );
    });

    test('drop in an element position becomes a marker, length is kept', () {
      Loggable.sanitizer =
          (ctx) => ctx.value == 'secret' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(['a', 'secret', 'c']);
      expect(out, contains('<dropped>'));
      expect(out, isNot(contains('secret')));
      expect(Loggable.objectToJson(['a', 'secret', 'c']), isNotNull);
    });

    test('json output sanitizes elements too', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'secret' ? '***' : ctx.value;

      expect(
        Loggable.objectToJson(['a', 'secret']).toString(),
        isNot(contains('secret')),
      );
    });

    test('collection limits still apply with a sanitizer', () {
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return ctx.value;
      };

      Loggable.objectToString(
        List<int>.generate(100, (i) => i),
        config: const LoggableConfig(collectionMaxCount: 3),
      );

      // Санитайзер не вызывается для того, что лимит не вывел:
      // корень + не больше выведенных элементов.
      expect(calls, lessThan(10));
    });

    test(
      'a candidate evicted by the length budget may still be offered '
      '(the rule must have no side effects)',
      () {
        // В отличие от collectionMaxCount (тест выше), бюджет длины
        // измеряет уже отрендеренный — и потому уже санитизированный —
        // текст кандидата, а буферизованный элемент может быть задним
        // числом вытеснен многоточием. Это не баг, а задокументированное
        // следствие того, как считается бюджет (см. дизайн-спеку,
        // раздел «Циклы, лимиты, ленивость»): значение может быть
        // предложено правилу и не попасть в вывод. Пин теста намеренно
        // жёсткий — если бюджет когда-нибудь станет считать размер без
        // рендера кандидата, это изменение контракта, и тест обязан
        // упасть.
        final offered = <String>[];
        Loggable.sanitizer = (ctx) {
          final value = ctx.value;
          if (value is String) offered.add(value);

          return value;
        };

        final out = Loggable.objectToString(
          Iterable<String>.generate(6, (i) => 'v$i'),
          config: const LoggableConfig(
            collectionShowIndexes: false,
            collectionShowCount: false,
            collectionMaxStringLength: 15,
          ),
        );

        // (a) вывод обрезан бюджетом, как и ожидается.
        expect(out, '("v0", "v1", …)');
        // (b) правилу предложили значение, которого нет в выводе.
        expect(offered, contains('v2'));
        expect(out, isNot(contains('v2')));
      },
    );

    test('an infinite iterable still does not hang', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final out = Loggable.objectToString(
        Iterable<int>.generate(1 << 30, (i) => i),
        config: const LoggableConfig(collectionMaxCount: 3),
      );

      expect(out, isNotEmpty);
    });

    test('cycles still render as a cycle marker', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final list = <Object?>[];
      list.add(list);

      expect(Loggable.objectToString(list), isNotEmpty);
      expect(Loggable.objectToJson(list).toString(), contains('cycle'));
    });
  });
}
