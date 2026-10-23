
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();

  String? _bloodGroup;
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? get _profileRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('healthProfile')
        .doc('profile');
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please sign in to view your health profile.');
      }

      final snapshot = await _profileRef!.get();
      final data = snapshot.data();

      if (!mounted) return;

      _heightController.text = data?['heightCm']?.toString() ?? '';
      _weightController.text = data?['weightKg']?.toString() ?? '';
      _allergiesController.text = data?['allergies'] as String? ?? '';
      _conditionsController.text =
          data?['conditions'] as String? ?? '';
      _medicationsController.text =
          data?['medications'] as String? ?? '';

      final savedBloodGroup = data?['bloodGroup'] as String?;
      const validBloodGroups = [
        'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown',
      ];

      _bloodGroup = validBloodGroups.contains(savedBloodGroup)
          ? savedBloodGroup
          : null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load health profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateMeasurement(String? value, String label) {
    if (value == null || value.trim().isEmpty) return null;

    final number = double.tryParse(value.trim());

    if (number == null || !number.isFinite || number <= 0) {
      return 'Enter a valid $label';
    }

    if (label == 'height' && number > 300) {
      return 'Enter a height below 300 cm';
    }

    if (label == 'weight' && number > 700) {
      return 'Enter a weight below 700 kg';
    }

    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final profileRef = _profileRef;

      if (user == null || profileRef == null) {
        throw Exception('Please sign in again to save your health profile.');
      }

      final heightText = _heightController.text.trim();
      final weightText = _weightController.text.trim();

      await profileRef.set({
        'heightCm':
            heightText.isEmpty ? null : double.parse(heightText),
        'weightKg':
            weightText.isEmpty ? null : double.parse(weightText),
        'bloodGroup': _bloodGroup,
        'allergies': _allergiesController.text.trim(),
        'conditions': _conditionsController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health profile saved successfully!'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save health profile: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save health profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Profile'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Your Health Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add information that may help personalize your health '
                    'experience. These details do not replace medical advice.',
                  ),
                  const SizedBox(height: 28),

                  _sectionTitle('Basic Measurements'),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          label: 'Height (cm)',
                          icon: Icons.height,
                          controller: _heightController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hint: 'e.g. 165',
                          validator: (value) =>
                              _validateMeasurement(value, 'height'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          label: 'Weight (kg)',
                          icon: Icons.monitor_weight_outlined,
                          controller: _weightController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hint: 'e.g. 60',
                          validator: (value) =>
                              _validateMeasurement(value, 'weight'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('Medical Information'),
                  DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood group (optional)',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'A+', child: Text('A+')),
                      DropdownMenuItem(value: 'A-', child: Text('A-')),
                      DropdownMenuItem(value: 'B+', child: Text('B+')),
                      DropdownMenuItem(value: 'B-', child: Text('B-')),
                      DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                      DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                      DropdownMenuItem(value: 'O+', child: Text('O+')),
                      DropdownMenuItem(value: 'O-', child: Text('O-')),
                      DropdownMenuItem(
                        value: 'Unknown',
                        child: Text('Unknown'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _bloodGroup = value),
                  ),
                  const SizedBox(height: 16),

                  _textField(
                    label: 'Known allergies',
                    icon: Icons.warning_amber_outlined,
                    controller: _allergiesController,
                    hint: 'Enter allergies, or leave blank',
                  ),
                  const SizedBox(height: 16),

                  _textField(
                    label: 'Existing medical conditions',
                    icon: Icons.medical_information_outlined,
                    controller: _conditionsController,
                    hint: 'e.g. diabetes, asthma, or none',
                  ),
                  const SizedBox(height: 16),

                  _textField(
                    label: 'Current medications',
                    icon: Icons.medication_outlined,
                    controller: _medicationsController,
                    hint: 'List medications, or leave blank',
                  ),
                  const SizedBox(height: 28),

                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Health Profile',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your health information is stored privately in your '
                    'account and can help personalize your health experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
