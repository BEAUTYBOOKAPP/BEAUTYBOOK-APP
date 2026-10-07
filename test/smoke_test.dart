import 'package:flutter_test/flutter_test.dart';
import 'package:beautybook/l10n/app_strings.dart';
import 'package:flutter/material.dart';

void main() {
  test('French localization helper selects French', () {
    const s = AppStrings(Locale('fr'));
    expect(s.t('Shop', 'Boutique'), 'Boutique');
  });
}
