import 'package:food_ninja/app/app.dart';
import 'package:food_ninja/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
