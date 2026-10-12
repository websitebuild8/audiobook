import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktaba_athariyya/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'unconfigured installations do not initialize Firebase or opt readers in',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(PushNotificationService.configured, isFalse);
    await PushNotificationService.instance.restore();
    expect(PushNotificationService.instance.enabled, isFalse);
    await expectLater(
        PushNotificationService.instance.setEnabled(true), throwsStateError);
    expect(PushNotificationService.instance.busy, isFalse);
    expect(PushNotificationService.instance.enabled, isFalse);
  });
}
