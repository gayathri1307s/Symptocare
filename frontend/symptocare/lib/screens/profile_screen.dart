import 'notification_settings_screen.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<String> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personalDetails')
          .doc('profile')
          .get();

      final name = doc.data()?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }

      return user.displayName ?? '';
    } catch (_) {
      return user.displayName ?? '';
    }
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FD),
        elevation: 0,
        foregroundColor: const Color(0xFF202B45),
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9EDF5)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 78,
                    width: 78,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF1FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<String>(
                    future: _loadUserName(),
                    builder: (context, snapshot) {
                      final name = snapshot.data?.trim() ?? '';

                      if (name.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202B45),
                          ),
                        ),
                      );
                    },
                  ),
                  const Text(
                    'Welcome to SymptoCare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF202B45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your health companion',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SymptoCareLogo(size: 34),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              'APP PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 10),

            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () => _openPage(
                context,
                const NotificationSettingsScreen(),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'INFORMATION & SUPPORT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 10),

            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About SymptoCare',
              subtitle: 'Learn about the app and its features',
              onTap: () => _openPage(
                context,
                const AboutSymptoCareScreen(),
              ),
            ),

            _SettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & FAQ',
              subtitle: 'Find answers to common questions',
              onTap: () => _openPage(
                context,
                const HelpFaqScreen(),
              ),
            ),

            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacy & Disclaimer',
              subtitle: 'Health information and app limitations',
              onTap: () => _openPage(
                context,
                const PrivacyDisclaimerScreen(),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SymptoCare provides health-risk insights '
                      'and is not a substitute for professional '
                      'medical advice or diagnosis.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF40516F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'SymptoCare • Health awareness made easier',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202B45),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textGrey,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.textGrey,
        ),
      ),
    );
  }
}

// ABOUT SYMPTOCARE
class AboutSymptoCareScreen extends StatelessWidget {
  const AboutSymptoCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        title: const Text('About SymptoCare'),
        backgroundColor: const Color(0xFFF6F8FD),
        foregroundColor: const Color(0xFF202B45),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: SymptoCareLogo(size: 72)),
          const SizedBox(height: 18),
          const Text(
            'Your Health Companion',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202B45),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'SymptoCare is an AI-assisted health-awareness '
            'application designed to help users explore symptoms, '
            'understand health information, and access health-risk '
            'screening features.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Color(0xFF40516F),
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.chat_outlined,
            title: 'Symptom Chat',
            description:
                'Explore health-related questions through the chat interface.',
          ),
          _InfoCard(
            icon: Icons.upload_file_outlined,
            title: 'Report Upload',
            description:
                  'Upload supported medical documents for analysis, where this feature is available.',
          ),
          _InfoCard(
            icon: Icons.monitor_heart_outlined,
            title: 'Health-Risk Screening',
            description:
                'Access the Diabetes and Chronic Kidney Disease screening forms.',
          ),
          const SizedBox(height: 12),
          const Text(
            'The availability and accuracy of individual features '
            'depend on their implementation. SymptoCare does not '
            'replace a qualified healthcare professional.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// HELP & FAQ
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'question': 'How do I use the symptom chat?',
      'answer': 'Open Start a New Chat and enter your health-related question or describe your symptoms. SymptoCare will provide AI-assisted health information based on your message and available information. The response is for general awareness only and is not a medical diagnosis.',
    },
    {
      'question': 'How do I check Diabetes or CKD risk?',
      'answer': 'Open the Diabetes or Chronic Kidney Disease (CKD) screening form, enter the requested health information, and submit it to view the model-generated risk estimate. This result is for health awareness only and does not confirm or rule out a medical condition. Please consult a qualified healthcare professional for medical assessment and advice.',
    },
    {
      'question': 'Can I upload a medical report?',
      'answer': 'If report upload and analysis are available in the current version of SymptoCare, upload your medical report and follow the instructions shown in the app. The analysis may have limitations and should not replace professional medical advice.',
    },
    {
      'question': 'Does SymptoCare diagnose diseases?',
      'answer': 'No. SymptoCare is designed to provide preliminary health information and AI-assisted risk estimates. It cannot diagnose diseases or replace a qualified healthcare professional. Please consult a doctor for diagnosis and treatment.',
    },
    {
      'question': 'What should I do if I feel unwell?',
      'answer': 'If you feel unwell or your symptoms persist or worsen, consult a qualified healthcare professional. Do not rely solely on SymptoCare for medical decisions. If you experience severe or life-threatening symptoms, seek emergency medical care immediately.',
    },
    {
      'question': 'Are my conversations permanently saved?',
      'answer': 'Chat history may not be permanently saved. Conversations managed by the backend can be lost when the backend restarts. Permanent chat storage is not currently guaranteed.',
    },
    {
      'question':'How accurate are the results?',
      'answer': 'SymptoCare uses AI-assisted tools to provide preliminary health information and risk estimates. Results may be inaccurate or incomplete and can vary depending on the information provided. They should not be treated as a diagnosis or a substitute for professional medical advice.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: const Color(0xFFF6F8FD),
        foregroundColor: const Color(0xFF202B45),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202B45),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find help with common app features.',
            style: TextStyle(color: AppTheme.textGrey),
          ),
          const SizedBox(height: 18),
          ..._faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9EDF5)),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  faq['question']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202B45),
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq['answer']!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Color(0xFF40516F),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// PRIVACY & DISCLAIMER
class PrivacyDisclaimerScreen extends StatelessWidget {
  const PrivacyDisclaimerScreen({super.key});

  Widget _section(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202B45),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.7,
              color: Color(0xFF40516F),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        title: const Text('Privacy & Disclaimer'),
        backgroundColor: const Color(0xFFF6F8FD),
        foregroundColor: const Color(0xFF202B45),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 58,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 18),
          _section(
            'Health Information Disclaimer',
            'SymptoCare is designed for health awareness and screening '
            'support. Its outputs are not a diagnosis, treatment plan, '
            'or substitute for advice from a qualified healthcare professional.',
          ),
          _section(
            'Accuracy and Limitations',
            'AI-generated responses, screening results, and report '
            'interpretations may be incomplete or inaccurate. Do not '
            'make medical decisions based only on this application.',
          ),
          _section(
            'Personal and Health Data',
            'Provide only the information needed to use the app. '
            'Personal and health information may be processed to provide '
            'SymptoCare features. Data storage, access, and retention '
            'depend on the systems configured in the app. Avoid sharing '
            'unnecessary sensitive information.',
          ),
          _section(
            'File Uploads',
            'Only upload documents you are authorized to share. '
            'The processing and retention of uploaded files depend '
            'on the configured upload and storage systems.',
          ),
          _section(
            'When to Seek Medical Care',
            'Consult a qualified healthcare professional about symptoms '
            'or concerning results. Seek urgent medical care for '
            'emergency symptoms rather than waiting for an app response.',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202B45),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
