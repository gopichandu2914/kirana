 import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'onboarding/language_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final loc = AppLocalizations.of(context);
    final auth = AuthService();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.get('profile'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 100, color: Colors.green),
              const SizedBox(height: 8),
              if (user != null) 
                 Text(user.email ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              Text(settings.shopName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue, size: 34),
                      title: const Text('Your Number', style: TextStyle(color: Colors.grey)),
                      subtitle: Text(
                        settings.whatsappNumber.isEmpty ? 'Not set' : settings.whatsappNumber,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.green, size: 34),
                      title: const Text('Supplier WhatsApp', style: TextStyle(color: Colors.grey)),
                      subtitle: Text(
                        settings.supplierWhatsapp.isEmpty ? 'Not set' : settings.supplierWhatsapp,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.orange, size: 34),
                      title: Text(loc.get('reorder_reminder_time'), style: const TextStyle(color: Colors.grey)),
                      subtitle: Text(
                        settings.reorderReminderTime.format(context),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.orange),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: settings.reorderReminderTime,
                          helpText: 'Select Reorder Reminder Time',
                        );
                        if (picked != null) {
                          await settings.saveReminderTime(picked);
                          await NotificationService().scheduleDailyReorderReminder(picked);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Daily Reminder set for ${picked.format(context)}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout, size: 28),
                label: const Text('Sign Out',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text('Do you want to log out and switch accounts? (Local data will be kept).'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LanguageScreen()),
                          (route) => false);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                   final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Full Reset?'),
                      content: const Text('DANGER: This will delete everything local. Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Reset All', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await auth.signOut();
                    await settings.reset();
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LanguageScreen()), (route) => false);
                  }
                },
                child: const Text('Clear All Local Data & Reset', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
