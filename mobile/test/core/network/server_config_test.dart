import 'package:cosmo_studio/core/network/server_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerUrlPolicy', () {
    test('rejects public HTTP endpoints in release mode', () {
      expect(
        ServerUrlPolicy.validate('http://example.test', isDebugMode: false),
        isNotNull,
      );
    });

    test('accepts HTTPS endpoints in release mode', () {
      expect(
        ServerUrlPolicy.validate('https://api.cosmo-studio.com',
            isDebugMode: false),
        isNull,
      );
    });

    test('rejects public HTTP hostnames resembling IPv6 local addresses', () {
      expect(
        ServerUrlPolicy.validate('http://fcevil.example', isDebugMode: true),
        isNotNull,
      );
    });
  });
}
