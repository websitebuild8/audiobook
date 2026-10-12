import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ނޯޓިފިކޭޝަން')),
        body: SafeArea(
            child: ListenableBuilder(
          listenable: PushNotificationService.instance,
          builder: (context, _) {
            final service = PushNotificationService.instance;
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'އާ ފޮތްތަކާއި އިޢުލާންތަކުގެ މަޢުލޫމާތު ލިބުމަށް ނޯޓިފިކޭޝަން އޮންކުރައްވާ.'),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: const Text('ނޯޓިފިކޭޝަން'),
                value: service.enabled,
                onChanged: !PushNotificationService.configured || service.busy
                    ? null
                    : (value) async {
                        try {
                          await service.setEnabled(value);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'ނޯޓިފިކޭޝަން ސެޓިންގްސް ބަދަލުނުކުރެވުނު. ފޯނުގެ ސެޓިންގްސް އާއި އިންޓަނެޓް ޗެކްކުރައްވާ.')));
                          }
                        }
                      },
              ),
              if (service.busy)
                const Center(child: CircularProgressIndicator()),
              if (!PushNotificationService.configured)
                const Text('މި ޚިދުމަތް އަދި ފަށައިފައެއް ނުވޭ.'),
            ]);
          },
        )),
      );
}
