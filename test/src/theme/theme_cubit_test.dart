import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ThemeCubit> cubitWith(Map<String, Object> saved) {
    SharedPreferences.setMockInitialValues(saved);
    return ThemeCubit.load();
  }

  test('follows the phone when nothing is saved', () async {
    expect((await cubitWith({})).state, ThemeMode.system);
  });

  test('starts with the saved choice', () async {
    expect((await cubitWith({'theme_mode': 'dark'})).state, ThemeMode.dark);
  });

  test('an unknown saved value falls back to the phone', () async {
    expect((await cubitWith({'theme_mode': 'blue'})).state, ThemeMode.system);
  });

  late SharedPreferences prefs;
  blocTest<ThemeCubit, ThemeMode>(
    'setMode emits and saves the choice',
    setUp: () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    },
    build: () => ThemeCubit(prefs),
    act: (cubit) => cubit.setMode(ThemeMode.light),
    expect: () => [ThemeMode.light],
    verify: (_) => expect(prefs.getString('theme_mode'), 'light'),
  );
}
