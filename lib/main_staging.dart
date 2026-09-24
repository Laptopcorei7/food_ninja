import 'package:food_ninja/app/app.dart';
import 'package:food_ninja/bootstrap.dart';
import 'package:food_ninja/src/theme/theme_cubit.dart';

Future<void> main() async {
  await bootstrap(() async => App(themeCubit: await ThemeCubit.load()));
}
