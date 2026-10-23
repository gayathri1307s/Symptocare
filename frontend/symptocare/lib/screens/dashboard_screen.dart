
import 'package:flutter/material.dart';
import 'account_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'chat_history_screen.dart';
import 'chat_screen.dart';
import 'ckd_check_screen.dart';
import 'diabetes_check_screen.dart';
import 'profile_screen.dart';
import 'upload_report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _openUploadReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadReportScreen(),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(),
      ),
    );
  }

  void _openAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountScreen(),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  void _openChatHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting and profile
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${FirebaseAuth.instance.currentUser?.displayName ?? 'User'}',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202B45),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'How can I help you today?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFEAF1FF),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Profile',
                      onPressed: () => _openAccount(context),
                      icon: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryBlue,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Start a New Chat
              _ActionCard(
                title: 'Start a New Chat',
                subtitle:
                    'Describe your symptoms, ask a question '
                    'or upload a report.',
                icon: Icons.chat_bubble_outline_rounded,
                background: const Color(0xFFEAF1FF),
                iconBackground: const Color(0xFFD7E5FF),
                accent: AppTheme.primaryBlue,
                onTap: () => _openChat(context),
              ),

              const SizedBox(height: 14),

              // Upload Report
              _ActionCard(
                title: 'Upload Report',
                subtitle:
                    'Share your medical reports '
                    '(PDF, image, etc.).',
                icon: Icons.upload_file_rounded,
                background: const Color(0xFFE6F7F1),
                iconBackground: const Color(0xFFD0F0E5),
                accent: const Color(0xFF159C7B),
                onTap: () => _openUploadReport(context),
              ),

              const SizedBox(height: 28),

              const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202B45),
                ),
              ),

              const SizedBox(height: 14),

              // Quick Access cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.history_rounded,
                      title: 'Chat History',
                      iconColor: AppTheme.primaryBlue,
                      iconBackground: const Color(0xFFEAF1FF),
                      onTap: () => _openChatHistory(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.water_drop_outlined,
                      title: 'Diabetes Check',
                      iconColor: const Color(0xFF159C7B),
                      iconBackground: const Color(0xFFE3F7EF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiabetesCheckScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.favorite_rounded,
                      title: 'CKD Check',
                      iconColor: const Color(0xFFE45B68),
                      iconBackground: const Color(0xFFFFECEF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CkdCheckScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Health disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE9EDF5),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SymptoCareLogo(size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SymptoCare provides health-risk insights, '
                        'not a medical diagnosis. Consult a qualified '
                        'healthcare professional for medical advice.',
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
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: true,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                    onTap: () => _openChatHistory(context),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: () => _openProfile(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Large dashboard action card
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color iconBackground;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.iconBackground,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202B45),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small Quick Access card
class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 112,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE9EDF5),
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 21,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF28334D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom navigation item
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primaryBlue
        : AppTheme.textGrey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 23,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
