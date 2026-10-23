
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'chat_screen.dart';
import 'prediction_result_screen.dart';

class CkdCheckScreen extends StatefulWidget {
  const CkdCheckScreen({super.key});

  @override
  State<CkdCheckScreen> createState() => _CkdCheckScreenState();
}

class _CkdCheckScreenState extends State<CkdCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Keep this URL when using your phone with adb reverse.
  static const String _apiUrl = 'http://127.0.0.1:8000/predict/ckd';

  final Map<String, TextEditingController> _numbers = {
    'age': TextEditingController(),
    'bp': TextEditingController(),
    'sg': TextEditingController(),
    'al': TextEditingController(),
    'su': TextEditingController(),
    'bgr': TextEditingController(),
    'bu': TextEditingController(),
    'sc': TextEditingController(),
    'sod': TextEditingController(),
    'pot': TextEditingController(),
    'hemo': TextEditingController(),
    'pcv': TextEditingController(),
    'wc': TextEditingController(),
    'rc': TextEditingController(),
  };

  final Map<String, String?> _choices = {
    'rbc': null,
    'pc': null,
    'pcc': null,
    'ba': null,
    'htn': null,
    'dm': null,
    'cad': null,
    'appet': null,
    'pe': null,
    'ane': null,
  };

  @override
  void dispose() {
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _label(String key) {
    const labels = {
      'age': 'Age (years)',
      'bp': 'Blood pressure',
      'sg': 'Specific gravity',
      'al': 'Urine albumin (dataset value)',
      'su': 'Urine sugar (dataset value)',
      'bgr': 'Blood glucose (dataset value)',
      'bu': 'Blood urea (dataset value)',
      'sc': 'Serum creatinine',
      'sod': 'Sodium',
      'pot': 'Potassium',
      'hemo': 'Haemoglobin',
      'pcv': 'Packed cell volume (PCV)',
      'wc': 'White blood cell count (WBC)',
      'rc': 'Red blood cell count (RBC)',
    };
    return labels[key] ?? key;
  }

  String? _validateNumber(String? value, String key) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter ${_label(key).toLowerCase()}';
    }
    final number = double.tryParse(value.trim());
    if (number == null || !number.isFinite || number < 0) {
      return 'Enter a valid non-negative number';
    }
    if (key == 'age' && (number < 1 || number > 120)) {
      return 'Enter an age from 1 to 120';
    }
    return null;
  }

  Widget _numberField(String key, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _numbers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _label(key),
          hintText: hint ?? 'Enter value from your medical record',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        validator: (value) => _validateNumber(value, key),
      ),
    );
  }

  Widget _choiceField(
    String key,
    String label,
    List<String> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _choices[key],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        items: options
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    value == 'notpresent'
                        ? 'Not present'
                        : value[0].toUpperCase() + value.substring(1),
                  ),
                ))
            .toList(),
        onChanged: _loading
            ? null
            : (value) => setState(() => _choices[key] = value),
        validator: (value) =>
            value == null ? 'Please select an option' : null,
      ),
    );
  }

  Future<void> _submitAssessment() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final input = <String, dynamic>{};

    for (final entry in _numbers.entries) {
      input[entry.key] = double.parse(entry.value.text.trim());
    }
    for (final entry in _choices.entries) {
      input[entry.key] = entry.value!;
    }

    setState(() => _loading = true);

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(input),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception(
          'The server returned HTTP ${response.statusCode}: '
          '${response.body}',
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['status'] == 'insufficient_data') {
        final missing = (result['missing_features'] as List? ?? [])
            .join(', ');
        throw Exception('Missing model inputs: $missing');
      }

      final prediction = result['prediction']?.toString().toLowerCase();
      final probabilities =
          result['probability'] as Map<String, dynamic>?;

      if (prediction != 'ckd' && prediction != 'notckd') {
        throw Exception('The server returned an unexpected prediction.');
      }

      final rawCkdProbability = probabilities?['ckd'];
      final ckdProbability = rawCkdProbability is num
          ? rawCkdProbability.toDouble()
          : null;

      if (ckdProbability != null &&
          (!ckdProbability.isFinite ||
              ckdProbability < 0 ||
              ckdProbability > 1)) {
        throw Exception('The server returned an invalid probability.');
      }

      final findings = <String>[
        'The trained model returned the class: '
            '${prediction == 'ckd' ? 'ckd' : 'notckd'}.',
        if (ckdProbability != null)
          'Model output for the CKD class: '
              '${(ckdProbability * 100).toStringAsFixed(2)}%.',
        'This is an experimental model output, not a diagnosis '
            'or a clinically validated estimate of personal risk.',
        'Discuss your measurements and any concerns with a qualified '
            'healthcare professional.',
      ];

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PredictionResultScreen(
            diseaseName: 'CKD Model Screening',
            riskLevel: prediction == 'ckd'
                ? 'CKD class predicted'
                : 'Not-CKD class predicted',
            probability: ckdProbability == null
                ? null
                : double.parse((ckdProbability * 100).toStringAsFixed(2)),
            keyFindings: findings,
            assessmentValues: input,
            onChatPressed: () {
              final message = '''
            I completed a CKD risk assessment in SymptoCare.

            Submitted measurements and responses:
            ${input.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

            Model class: $prediction
            CKD class probability: ${ckdProbability == null ? 'Unavailable' : '${(ckdProbability * 100).toStringAsFixed(2)}%'}

            Please explain these model outputs and the measurements in simple language.
            Clarify that this is an experimental screening model output, not a diagnosis.
            Do not diagnose me or infer missing medical information. Explain what I could
            discuss with a qualified healthcare professional.
            ''';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(initialMessage: message),
                ),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete CKD screening: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3860F5);
    const darkBlue = Color(0xFF172B52);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8FD),
        foregroundColor: darkBlue,
        elevation: 0,
        title: const Text(
          'CKD Check',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Enter values from your medical records. '
                  'All 24 model features are required. If you do not '
                  'know a value or medical-history response, do not guess. '
                  'This experimental model is not a diagnostic tool.',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Numeric measurements',
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ...[
                _numberField('age'),
                _numberField('bp'),
                _numberField('sg', hint: 'Example: 1.020'),
                _numberField('al'),
                _numberField('su'),
                _numberField('bgr'),
                _numberField('bu'),
                _numberField('sc'),
                _numberField('sod'),
                _numberField('pot'),
                _numberField('hemo'),
                _numberField('pcv'),
                _numberField('wc'),
                _numberField('rc'),
              ],
              const SizedBox(height: 8),
              const Text(
                'Medical and urine indicators',
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _choiceField('rbc', 'Red blood cells (urine)', [
                'normal',
                'abnormal',
              ]),
              _choiceField('pc', 'Pus cells', [
                'normal',
                'abnormal',
              ]),
              _choiceField('pcc', 'Pus cell clumps', [
                'present',
                'notpresent',
              ]),
              _choiceField('ba', 'Bacteria in urine', [
                'present',
                'notpresent',
              ]),
              _choiceField('htn', 'History of hypertension', [
                'yes',
                'no',
              ]),
              _choiceField('dm', 'History of diabetes mellitus', [
                'yes',
                'no',
              ]),
              _choiceField('cad', 'History of coronary artery disease', [
                'yes',
                'no',
              ]),
              _choiceField('appet', 'Appetite', [
                'good',
                'poor',
              ]),
              _choiceField('pe', 'Pedal oedema', [
                'yes',
                'no',
              ]),
              _choiceField('ane', 'Anaemia indicator', [
                'yes',
                'no',
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submitAssessment,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    _loading ? 'Submitting...' : 'Run CKD Model Screening',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: blue.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SymptoCare supports health awareness and does not replace '
                'professional medical advice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8995A8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
