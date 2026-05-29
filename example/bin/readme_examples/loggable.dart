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

Future<void> main() async {
  print('----- Person -----');
  person1.run();
  person2.run();
  person3.run();

  print('----- Full/short view -----');
  point1.run();
  speed1.run();
  point2.run();
  speed2.run();

  print('----- Multi view -----');
  route.run();

  print('----- mapBuilder/builder -----');
  not_loggable1.run();

  print('----- Type converter -----');
  not_loggable2.run();
}
