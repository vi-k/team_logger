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
      expect(
        Loggable.objectToString(data),
        '{₌₂ user: "ann", password: "***"}',
      );
      expect(Loggable.objectToJson(data), {'user': 'ann', 'password': '***'});
    });

    test('drop removes the entry with its separator', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      const data = {'a': 1, 'password': 'hunter2', 'c': 3};
      expect(Loggable.objectToString(data), '{₌₃ a: 1, c: 3}');
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
        '{₌₁ card: "<redacted>"}',
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
          '{₌₃ a: 1, b: $droppedText, c: 3}',
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

      // Санитайзер не вызывается для того, что лимит не вывел: корень
      // плюс ровно три выведенных элемента (первый, последний и один
      // промежуточный). Число точное — «меньше десяти» пропускало
      // лишний рендер отсечённого хвоста.
      expect(calls, 4);
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

  group('Loggable.sanitizer — props', () {
    tearDown(() => Loggable.sanitizer = null);

    test('sanitizes props of a Loggable object in both outputs', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final user = _User('ann', 'hunter2');
      expect(Loggable.objectToString(user), contains('"***"'));
      expect(Loggable.objectToString(user), isNot(contains('hunter2')));
      expect(
        Loggable.objectToJson(user).toString(),
        isNot(contains('hunter2')),
      );
    });

    test('drop removes the prop entirely', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(_User('ann', 'hunter2'));
      expect(out, contains('ann'));
      expect(out, isNot(contains('password')));
    });

    test('the sanitizer sees the view, not the raw value', () {
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        if (ctx.depth > 0) seen.add(ctx.value);

        return ctx.value;
      };

      Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..prop('card', 'raw-pan', view: 'view-pan'),
      );

      expect(seen, ['view-pan']);
    });

    test('replacing a prop with a view leaks neither value nor view', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'card' ? '***' : ctx.value;

      final data = Loggable.builder(const Object(), name: 'D')
        ..prop('card', 'raw-pan', view: 'view-pan');

      final out = Loggable.objectToString(data);
      expect(out, contains('***'));
      expect(out, isNot(contains('raw-pan')));
      expect(out, isNot(contains('view-pan')));
      expect(
        Loggable.objectToJson(data).toString(),
        isNot(contains('raw-pan')),
      );
    });

    test('computed props are visible through their view', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'total' ? '***' : ctx.value;

      final out = Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..computed('total', 'secret-total'),
      );

      expect(out, contains('***'));
      expect(out, isNot(contains('secret-total')));
    });

    test('LoggableView is replaced as a whole', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'x' ? '***' : ctx.value;

      final out = Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..prop('x', 1, view: const LoggableView(42, units: 'kg')),
      );

      expect(out, contains('***'));
      expect(out, isNot(contains('42')));
    });

    test('mapBuilder props are sanitized too', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(
        Loggable.mapBuilder()
          ..prop('a', 1, units: 'kg')
          ..prop('password', 'hunter2'),
      );

      expect(out, '{a: 1kg}');
    });

    test('LoggableWrapper is transparent', () {
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx.value);

        return ctx.value;
      };

      Loggable.objectToString(
        Loggable.from('hunter2', config: const LoggableConfig()),
      );

      expect(seen, ['hunter2']);
    });

    test(
      'sanitizes a single prop exactly once — the root path does not '
      're-fire on it',
      () {
        // Свойство должно попадать под санитайзер ровно один раз — своим
        // собственным вызовом (depth > 0). До фикса значение свойства
        // рендерилось через objectToString с пустым стеком сегментов, что
        // било по корневому пути (depth 0) вместо/вместе с позиционным.
        // Правило вида `(ctx) => ctx.name == 'p' ? Sanitize.drop : ctx.value`
        // ломается при повторном применении к собственному результату —
        // поэтому здесь важен именно счётчик вызовов, а не факт замены.
        var propCalls = 0;
        Loggable.sanitizer = (ctx) {
          if (ctx.depth > 0) propCalls++;

          return ctx.value;
        };

        Loggable.objectToString(
          Loggable.builder(const Object(), name: 'D')..prop('a', 1),
        );

        expect(propCalls, 1);
      },
    );

    test(
      'sanitizes a single prop exactly once in JSON output too',
      () {
        var propCalls = 0;
        Loggable.sanitizer = (ctx) {
          if (ctx.depth > 0) propCalls++;

          return ctx.value;
        };

        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')..prop('a', 1),
        );

        expect(propCalls, 1);
      },
    );
  });
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
