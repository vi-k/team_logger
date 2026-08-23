import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Regressions from the final review of the sanitizer feature (0.6.0).
///
/// Each group pins one defect that review found — the tests are deliberately
/// strict: they must fail if the behavior reverts to its pre-review state.
void main() {
  group('sanitizer review — root reentrancy', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a rule that renders its own value does not recurse forever', () {
      // The contract forbids a rule from rendering (see Loggable.sanitizer),
      // but breaking the contract must not hang the process: before the fix
      // _sanitizeRoot called the rule with an empty segment stack, so an
      // objectToString from inside the rule landed in the root branch again.
      Loggable.sanitizer = (ctx) =>
          Loggable.objectToString(ctx.value).contains('secret')
              ? '***'
              : ctx.value;

      expect(Loggable.objectToString('secret'), '"***"');
      expect(Loggable.objectToJson('secret'), '***');
    });

    test('a render from inside the root rule does not re-enter the root', () {
      // Rendering from inside a rule breaks the contract (including
      // implicitly: interpolating '${ctx.value}' for a LoggableWrapper calls
      // objectToString). It should cost an extra pass, not a hang: the root
      // branch must not be re-entered.
      var rootCalls = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.name == null) {
          rootCalls++;
          Loggable.objectToString(ctx.value);
          Loggable.objectToJson(ctx.value);
        }

        return ctx.value;
      };

      expect(Loggable.objectToString({'a': 1}), '{₌₁ a: 1}');
      expect(rootCalls, 1);
    });

    test('the guard segment is not part of the path or the depth', () {
      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({'a': 1});

      expect(seen, {'|null': 0, 'a|a': 1});
    });
  });

  group('sanitizer review — a replacement is rendered normally', () {
    tearDown(() => Loggable.sanitizer = null);

    test('children of a replacement container ARE offered to the rule', () {
      // The walk never descends into the ORIGINAL, but the replacement is
      // rendered as an ordinary value — so its own children go through the
      // rule.
      final names = <String?>[];
      Loggable.sanitizer = (ctx) {
        names.add(ctx.name);

        return ctx.name == 'card' ? {'inner': 'x'} : ctx.value;
      };

      expect(
        Loggable.objectToString({
          'card': {'pan': '4111', 'cvv': '123'},
        }),
        '{₌₁ card: {₌₁ inner: "x"}}',
      );
      // 'pan'/'cvv' — the original's children — were not offered; 'inner',
      // the replacement's child, was.
      expect(names, [null, 'card', 'inner']);
    });

    test('the path of a replacement child continues the original path', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add(ctx.path);

        return ctx.name == 'card' ? {'inner': 'x'} : ctx.value;
      };

      Loggable.objectToJson({
        'card': {'pan': '4111'},
      });

      expect(paths, ['', 'card', 'card.inner']);
    });
  });

  group('sanitizer review — LoggableWrapper at child positions', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a wrapper in a map entry is transparent', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'hunter2' ? '***' : ctx.value;

      final data = {'password': Loggable.from('hunter2')};
      expect(Loggable.objectToString(data), '{₌₁ password: "***"}');
      expect(Loggable.objectToJson(data), {'password': '***'});
    });

    test('a wrapper in a prop is transparent', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'hunter2' ? '***' : ctx.value;

      final data = Loggable.mapBuilder()
        ..prop('password', Loggable.from('hunter2'));

      // mapBuilder is a structure of props, not a collection, so there is no
      // counter.
      expect(Loggable.objectToString(data), '{password: "***"}');
      expect(Loggable.objectToJson(data), {'password': '***'});
    });

    test('a wrapper in a collection element is transparent', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'hunter2' ? '***' : ctx.value;

      final data = [Loggable.from('hunter2')];
      expect(Loggable.objectToString(data), isNot(contains('hunter2')));
      expect(
        Loggable.objectToJson(data).toString(),
        isNot(contains('hunter2')),
      );
    });

    test('an untouched wrapper keeps its own config', () {
      // The rule returned the contents unchanged — render the ORIGINAL
      // wrapper, otherwise its config (units here) would be lost.
      Loggable.sanitizer = (ctx) => ctx.value;

      final data = {
        'n': Loggable.from(1, config: const LoggableConfig(units: 'kg')),
      };
      expect(Loggable.objectToString(data), '{₌₁ n: 1kg}');
    });

    test('a wrapper value is offered exactly once', () {
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        if (ctx.name != null) seen.add(ctx.value);

        return ctx.value;
      };

      Loggable.objectToString({'password': Loggable.from('hunter2')});

      expect(seen, ['hunter2']);
    });
  });

  group('sanitizer review — sentinels are distinct objects', () {
    tearDown(() => Loggable.sanitizer = null);

    test('const Object() as a replacement is not read as "unset"', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'secret' ? const Object() : ctx.value;

      final data = Loggable.mapBuilder()..prop('secret', 'hunter2');
      expect(Loggable.objectToString(data), isNot(contains('hunter2')));
      expect(
        Loggable.objectToJson(data).toString(),
        isNot(contains('hunter2')),
      );
    });

    test('const Object() as a replacement is not read as a guard segment', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add(ctx.path);

        return ctx.name == null ? const Object() : ctx.value;
      };

      expect(Loggable.objectToString({'a': 1}), isNot(contains('a: 1')));
      // The root replacement was rendered but never offered to the rule
      // again.
      expect(paths, ['']);
    });
  });

  group('sanitizer review — units are not applied to a replacement', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a numeric replacement of a prop with units drops the units', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'w' ? 0 : ctx.value;

      final data = Loggable.mapBuilder()..prop('w', 12.5, units: 'kg');
      expect(Loggable.objectToString(data), '{w: 0}');
      expect(Loggable.objectToJson(data), {'w': 0});
    });

    test('units survive when the rule does not touch the value', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final data = Loggable.mapBuilder()..prop('w', 12.5, units: 'kg');
      expect(Loggable.objectToString(data), '{w: 12.5kg}');
      expect(Loggable.objectToJson(data), {
        'w': {':v': 12.5, ':u': 'kg'},
      });
    });
  });

  group('sanitizer review — Prop rendered directly', () {
    tearDown(() => Loggable.sanitizer = null);

    test('Prop.toLogString without `sanitized:` still applies the rule', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      // LoggableData.props is public: an in-app viewer may well render props
      // one by one.
      final props = _User('ann', 'hunter2').logClassInfo().props;
      final out = props.map((p) => p.toLogString()).join(', ');

      expect(out, contains('ann'));
      expect(out, isNot(contains('hunter2')));
    });

    test('Prop.toMapEntry without `sanitized:` still applies the rule', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final props = _User('ann', 'hunter2').logClassInfo().props;
      final entries = Map.fromEntries(props.map((p) => p.toMapEntry()));

      expect(entries, {'name': 'ann', 'password': '***'});
    });

    test('Prop.toString is sanitized too', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final props = _User('ann', 'hunter2').logClassInfo().props;
      expect(props.last.toString(), isNot(contains('hunter2')));
    });

    test('rendering through LoggableData still fires the rule once', () {
      // LoggableData always passes `sanitized:`, so the fallback above must
      // not make the rule fire twice.
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.name == 'password') calls++;

        return ctx.value;
      };

      Loggable.objectToString(_User('ann', 'hunter2'));
      expect(calls, 1);

      calls = 0;
      Loggable.objectToJson(_User('ann', 'hunter2'));
      expect(calls, 1);

      calls = 0;
      Loggable.objectToString(
        Loggable.mapBuilder()..prop('password', 'hunter2'),
      );
      expect(calls, 1);

      calls = 0;
      Loggable.objectToJson(
        Loggable.mapBuilder()..prop('password', 'hunter2'),
      );
      expect(calls, 1);
    });
  });

  group('sanitizer review — JSON shape after a drop', () {
    tearDown(() => Loggable.sanitizer = null);

    test('dropping the only unnamed prop collapses the list back to a map', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final json = Loggable.objectToJson(
        Loggable.builder(const Object(), name: 'D')
          ..prop('a', 1)
          ..prop('password', 'hunter2', showName: false),
      );

      expect((json! as Map)[':p'], {'a': 1});
    });

    test('the list shape is kept while an unnamed prop survives', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final json = Loggable.objectToJson(
        Loggable.builder(const Object(), name: 'D')
          ..prop('a', 1)
          ..prop('b', 2, showName: false),
      );

      expect((json! as Map)[':p'], isA<List<Object?>>());
    });
  });

  group('sanitizer review — a throwing rule', () {
    tearDown(() => Loggable.sanitizer = null);

    test('leaves the segment stack uncorrupted for the next render', () {
      Loggable.sanitizer = (ctx) {
        if (ctx.name == 'boom') throw StateError('boom');

        return ctx.value;
      };

      expect(
        () => Loggable.objectToString({
          'a': {'boom': 1},
        }),
        throwsStateError,
      );
      expect(
        () => Loggable.objectToJson({
          'a': {'boom': 1},
        }),
        throwsStateError,
      );

      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({'x': 1});

      expect(seen, {'|null': 0, 'x|x': 1});
    });

    test('a throw at the root leaves the guard segment popped', () {
      Loggable.sanitizer = (ctx) => throw StateError('boom');

      expect(() => Loggable.objectToString('a'), throwsStateError);

      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({'x': 1});

      expect(seen, {'|null': 0, 'x|x': 1});
    });

    test('a throw from a prop rule leaves the stack uncorrupted', () {
      Loggable.sanitizer = (ctx) {
        if (ctx.name == 'boom') throw StateError('boom');

        return ctx.value;
      };

      expect(
        () => Loggable.objectToString(
          Loggable.mapBuilder()..prop('boom', 1),
        ),
        throwsStateError,
      );

      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({'x': 1});

      expect(seen, {'|null': 0, 'x|x': 1});
    });
  });

  group('sanitizer review — LoggableMultiData.toString', () {
    tearDown(() => Loggable.sanitizer = null);

    test('applies the rule by entry key', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final data = LoggableMultiData({'req': 'ok', 'password': 'hunter2'});
      expect(data.toString(), 'req: "ok"');
    });

    test('a nested value keeps the section key in its path', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add(ctx.path);

        return ctx.value;
      };

      LoggableMultiData({
        'req': {'pan': '4111'},
      }).toString();

      // The first observation is the ROOT (empty path): an alternative
      // renderer must offer the data object itself to the rule as well.
      expect(paths, ['', 'req', 'req.pan']);
    });

    test('offers the root value to the rule', () {
      // Before the fix toString() went straight into the section walk,
      // skipping the root offer that lives in objectToString/objectToJson.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(LoggableMultiData({'s': 'topsecret'}).toString(), '');
    });

    test('renders a root replacement instead of the sections', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(LoggableMultiData({'s': 'topsecret'}).toString(), '"***"');
    });

    test('offers the root exactly once', () {
      var roots = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.depth == 0) roots++;

        return ctx.value;
      };

      LoggableMultiData({'s': 'topsecret'}).toString();

      expect(roots, 1);
    });
  });

  group('sanitizer review — a raw structural view keeps the parent path', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a Loggable view nests under the property path', () {
      // A raw view (and LoggableView) used to render without the property
      // segment: the nested walk started from an empty path and, on top of
      // that, offered its own argument to the rule a second time as a root.
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add(ctx.path);

        return ctx.value;
      };

      final data = Loggable.mapBuilder()
        ..prop('user', 0, view: Loggable.from({'password': 'hunter2'}));

      Loggable.objectToString(data);
      expect(paths, ['', 'user', 'user.password']);

      paths.clear();
      Loggable.objectToJson(data);
      expect(paths, ['', 'user', 'user.password']);
    });

    test('a rule on the full path redacts the nested value', () {
      Loggable.sanitizer =
          (ctx) => ctx.path == 'user.password' ? '***' : ctx.value;

      final data = Loggable.mapBuilder()
        ..prop('user', 0, view: Loggable.from({'password': 'hunter2'}));

      expect(Loggable.objectToString(data), '{user: {₌₁ password: "***"}}');
      expect(
        Loggable.objectToJson(data).toString(),
        isNot(contains('hunter2')),
      );
    });

    test('a rule on the short path leaves a sibling top-level prop alone', () {
      // Over-redaction: the shortened path collided with a real top-level
      // property and wiped that one out too.
      Loggable.sanitizer = (ctx) => ctx.path == 'pan' ? '***' : ctx.value;

      final data = Loggable.mapBuilder()
        ..prop('card', 'unused', view: Loggable.from({'pan': '4111'}))
        ..prop('pan', '5555');

      expect(
        Loggable.objectToString(data),
        '{card: {₌₁ pan: "4111"}, pan: "***"}',
      );
    });

    test('the value under a raw view is offered exactly once', () {
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return ctx.value;
      };

      final data = Loggable.mapBuilder()
        ..prop('user', 0, view: Loggable.from({'password': 'hunter2'}));

      // The root, the `user` prop, the nested `password` — and nothing
      // more.
      Loggable.objectToString(data);
      expect(calls, 3);

      calls = 0;
      Loggable.objectToJson(data);
      expect(calls, 3);
    });

    test('a LoggableView.convert converter renders under the property', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add(ctx.path);

        return ctx.value;
      };

      final data = Loggable.mapBuilder()
        ..prop(
          'user',
          {'password': 'hunter2'},
          view: LoggableView.convert<Map<String, Object?>>(
            (value, theme, depth) =>
                Loggable.objectToString(value, theme: theme, depth: depth),
          ),
        );

      Loggable.objectToString(data);
      expect(paths, ['', 'user', 'user.password']);

      paths.clear();
      Loggable.objectToJson(data);
      expect(paths, ['', 'user', 'user.password']);
    });
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
