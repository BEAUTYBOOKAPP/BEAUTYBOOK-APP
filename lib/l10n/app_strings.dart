import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);
  bool get fr => locale.languageCode == 'fr';
  String t(String en, String french) => fr ? french : en;
  static AppStrings of(BuildContext c) => AppStrings(Localizations.localeOf(c));
}
