import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS storage construction selects secure storage', () {
    final storage = AppStorage.createForPlatform(isMacOS: true);

    expect(storage.usesSecureStorage, isTrue);
    expect(storage.usesSharedPreferences, isFalse);
  });
}
