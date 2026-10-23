import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openLoginScreen();
  }

  Future<void> _openLoginScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    debugPrint('SymptoCare: Navigating to LoginScreen');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFEAF1FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SymptoCareLogo(size: 112),
              const SizedBox(height: 24),
              const Text(
                'SymptoCare',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Understand your symptoms.\nTake charge of your health.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}