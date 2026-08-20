import 'package:example/readme_examples/frames.dart';
import 'package:example/readme_examples/loggable/not_loggable1.dart'
    as not_loggable1;
import 'package:example/readme_examples/loggable/not_loggable2.dart'
    as not_loggable2;
import 'package:example/readme_examples/loggable/route_info.dart' as route;
import 'package:example/readme_examples/loggable/person1.dart' as person1;
import 'package:example/readme_examples/loggable/person2.dart' as person2;
import 'package:example/readme_examples/loggable/person3.dart' as person3;
import 'package:example/readme_examples/loggable/point1.dart' as point1;
import 'package:example/readme_examples/loggable/point2.dart' as point2;
import 'package:example/readme_examples/loggable/speed1.dart' as speed1;
import 'package:example/readme_examples/loggable/speed2.dart' as speed2;

final frames = <String, Frame>{
  'loggable_1': _person,
  'loggable_2': _fullShortView,
  'loggable_3': _multiView,
  'loggable_4': _mapBuilder,
  'loggable_5': _typeConverter,
};

void main(List<String> args) => runFrames(frames, args);

/// Три способа описать один и тот же класс.
void _person() {
  person1.run();
  person2.run();
  person3.run();
}

/// Полное и короткое представление значения.
void _fullShortView() {
  point1.run();
  speed1.run();
  point2.run();
  speed2.run();
}

/// Несколько представлений одного значения сразу.
void _multiView() {
  route.run();
}

/// Описание чужого класса снаружи.
void _mapBuilder() {
  not_loggable1.run();
}

/// Конвертер типа, зарегистрированный глобально.
void _typeConverter() {
  not_loggable2.run();
}
