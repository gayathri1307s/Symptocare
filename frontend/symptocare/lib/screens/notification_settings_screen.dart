
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _healthRemindersEnabled = true;
  bool _reportUpdatesEnabled = true;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F8FD);
    const textColor = Color(0xFF202B45);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EDF5)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF356AE6),
                size: 28,
              ),
              title: const Text(
                'Enable notifications',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Turn notification preferences on or off.',
              ),
              value: _notificationsEnabled,
              activeThumbColor: const Color(0xFF356AE6),
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NOTIFICATION TYPES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Color(0xFF77839A),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EDF5)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Health reminders'),
                  subtitle: const Text(
                    'General health-awareness reminders',
                  ),
                  value: _healthRemindersEnabled,
                  activeThumbColor: const Color(0xFF356AE6),
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() {
                            _healthRemindersEnabled = value;
                          });
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Report updates'),
                  subtitle: const Text(
                    'Updates about report analysis',
                  ),
                  value: _reportUpdatesEnabled,
                  activeThumbColor: const Color(0xFF356AE6),
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() {
                            _reportUpdatesEnabled = value;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'These settings currently apply only while this screen '
            'remains open. Preferences are not saved permanently, '
            'and actual notifications are not connected yet.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xFF77839A),
            ),
          ),
        ],
      ),
    );
  }
}
