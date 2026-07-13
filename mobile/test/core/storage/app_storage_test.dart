import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS storage construction selects secure storage', () {
    const macOsSecureStorage = FlutterSecureStorage(
      mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    const standardSecureStorage = FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    final storage = AppStorage.createForPlatform(
      isMacOS: true,
      macOsSecureStorage: macOsSecureStorage,
      standardSecureStorage: standardSecureStorage,
    );

    expect(storage.secureStorage, same(macOsSecureStorage));
    expect(storage.secureStorage, isNot(same(standardSecureStorage)));
  });
}
