import 'package:cosmo_studio/features/salary/presentation/screens/salary_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salary ring uses ASCII body with only a soft halo underneath', () {
    expect(SalaryRingVisualProfile.trackAlpha, inInclusiveRange(0.04, 0.08));
    expect(SalaryRingVisualProfile.earnedSolidCoreAlpha, 0);
    expect(SalaryRingVisualProfile.pendingSolidCoreAlpha, 0);
    expect(SalaryRingVisualProfile.earnedBloomAlpha, lessThanOrEqualTo(0.22));
    expect(SalaryRingVisualProfile.pendingBloomAlpha, lessThanOrEqualTo(0.18));
  });

  test('salary ring ambient breathing is disabled for idle performance', () {
    expect(SalaryRingVisualProfile.enableAmbientBreathing, isFalse);
    expect(SalaryRingVisualProfile.staticBreatheValue, inInclusiveRange(0.0, 1.0));
  });
}
