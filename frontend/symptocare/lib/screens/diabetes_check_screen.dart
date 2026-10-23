
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'prediction_result_screen.dart';

class DiabetesCheckScreen extends StatefulWidget {
  const DiabetesCheckScreen({super.key});

  @override
  State<DiabetesCheckScreen> createState() =>
      _DiabetesCheckScreenState();
}

class _DiabetesCheckScreenState extends State<DiabetesCheckScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _bmiController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _glucoseController = TextEditingController();

  String? _gender;
  String? _smokingHistory;
  int? _hypertension;
  int? _heartDisease;
  bool _isLoading = false;

  static const _primaryBlue = Color(0xFF3860F5);
  static const _darkBlue = Color(0xFF172B52);
  static const _pageBackground = Color(0xFFF5F8FD);

  // Uses the existing Android adb reverse setup.
  static const _baseUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    _ageController.dispose();
    _bmiController.dispose();
    _hba1cController.dispose();
    _glucoseController.dispose();
    super.dispose();
  }

  double? _number(String? value) =>
      double.tryParse(value?.trim() ?? '');

  String? _validateNumber(
    String? value, {
    required String name,
    required double min,
    required double max,
    bool wholeNumber = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $name';
    }

    final number = _number(value);

    if (number == null || !number.isFinite) {
      return 'Enter a valid number';
    }

    if (number < min || number > max) {
      return 'Enter a value from $min to $max';
    }

    if (wholeNumber && number % 1 != 0) {
      return 'Enter a whole number';
    }

    return null;
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required double min,
    required double max,
    required String name,
    bool wholeNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.edit_outlined),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: Color(0xFFE5ECF7),
            ),
          ),
        ),
        validator: (value) => _validateNumber(
          value,
          name: name,
          min: min,
          max: max,
          wholeNumber: wholeNumber,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        items: items,
        onChanged: _isLoading ? null : onChanged,
        validator: (selected) =>
            selected == null ? 'Please select $label' : null,
      ),
    );
  }

  Future<void> _submitPrediction() async {
    FocusScope.of(context).unfocus();

    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        'gender': _gender,
        'age': _number(_ageController.text),
        'hypertension': _hypertension,
        'heart_disease': _heartDisease,
        'smoking_history': _smokingHistory,
        'bmi': _number(_bmiController.text),
        'HbA1c_level': _number(_hba1cController.text),
        'blood_glucose_level': _number(_glucoseController.text),
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/predict/diabetes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      // Temporary debugging: inspect the API result in the Flutter terminal.
      debugPrint('Diabetes API status: ${response.statusCode}');
      debugPrint('Diabetes API response: ${response.body}');
      debugPrint('Diabetes request sent successfully.');

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('The server returned an unexpected response.');
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final detail = decoded['detail'];
        throw Exception(
          detail is String
              ? detail
              : 'The server rejected the request '
                  '(HTTP ${response.statusCode}).',
        );
      }

      if (decoded['status'] == 'insufficient_data') {
        final missing = decoded['missing_features'];
        throw Exception(
          'The model needs additional features: '
          '${missing is List ? missing.join(', ') : 'unknown'}.',
        );
      }

      final rawPrediction = decoded['prediction'];
      final prediction = rawPrediction is num
          ? rawPrediction.toInt()
          : int.tryParse('$rawPrediction');

      if (prediction == null || (prediction != 0 && prediction != 1)) {
        throw Exception(
          'The model response did not contain a valid prediction.',
        );
      }

      final rawProbability = decoded['probability'];
      final probabilityValue = rawProbability is num
          ? rawProbability.toDouble()
          : double.tryParse('$rawProbability');

      final probability = probabilityValue != null &&
              probabilityValue.isFinite &&
              probabilityValue >= 0 &&
              probabilityValue <= 1
          ? probabilityValue * 100
          : null;
          
      final riskLabel = prediction == 1
          ? 'Positive model prediction'
          : 'Negative model prediction';

      final findings = <String>[
        'The trained model returned class $prediction.',
        if (probability != null)
        'Model probability for the positive class: '
            '${probability.toStringAsFixed(2)}%.',
        'This is a screening estimate, not a medical diagnosis.',
      ];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PredictionResultScreen(
            diseaseName: 'Diabetes Risk Assessment',
            riskLevel: riskLabel,
            probability: probability,
            keyFindings: findings,
            assessmentValues: requestBody,
            modelPrediction: prediction,
            rawProbability: probabilityValue,
          ),
        ),
      );
    } on Exception catch (error) {
      debugPrint('Diabetes prediction exception: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prediction failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Unexpected diabetes prediction error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong while processing the prediction.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _darkBlue,
        title: const Text(
          'Diabetes Check',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Enter the health information below to request '
                  'a prediction from your trained diabetes model. '
                  'Use accurate measurements from your records.',
                  style: TextStyle(
                    color: _darkBlue,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Personal Details',
                style: TextStyle(
                  color: _darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _numberField(
                controller: _ageController,
                label: 'Age (years)',
                hint: 'Enter age',
                min: 1,
                max: 120,
                name: 'age',
                wholeNumber: true,
              ),
              _dropdown<String>(
                label: 'Gender',
                value: _gender,
                items: const [
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text('Female'),
                  ),
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text('Male'),
                  ),
                ],
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 4),
              const Text(
                'Medical History',
                style: TextStyle(
                  color: _darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _dropdown<int>(
                label: 'Hypertension',
                value: _hypertension,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('No')),
                  DropdownMenuItem(value: 1, child: Text('Yes')),
                ],
                onChanged: (value) =>
                    setState(() => _hypertension = value),
              ),
              _dropdown<int>(
                label: 'Heart disease',
                value: _heartDisease,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('No')),
                  DropdownMenuItem(value: 1, child: Text('Yes')),
                ],
                onChanged: (value) =>
                    setState(() => _heartDisease = value),
              ),
              _dropdown<String>(
                label: 'Smoking history',
                value: _smokingHistory,
                items: const [
                  DropdownMenuItem(
                    value: 'never',
                    child: Text('Never'),
                  ),
                  DropdownMenuItem(
                    value: 'No Info',
                    child: Text('Unknown / No information'),
                  ),
                  DropdownMenuItem(
                    value: 'current',
                    child: Text('Current'),
                  ),
                  DropdownMenuItem(
                    value: 'former',
                    child: Text('Former'),
                  ),
                  DropdownMenuItem(
                    value: 'ever',
                    child: Text('Ever'),
                  ),
                  DropdownMenuItem(
                    value: 'not current',
                    child: Text('Not current'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _smokingHistory = value),
              ),
              const SizedBox(height: 4),
              const Text(
                'Health Measurements',
                style: TextStyle(
                  color: _darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _numberField(
                controller: _bmiController,
                label: 'BMI',
                hint: 'Enter BMI from your records',
                min: 1,
                max: 100,
                name: 'BMI',
              ),
              _numberField(
                controller: _hba1cController,
                label: 'HbA1c level (%)',
                hint: 'Enter HbA1c result',
                min: 0.1,
                max: 30,
                name: 'HbA1c level',
              ),
              _numberField(
                controller: _glucoseController,
                label: 'Blood glucose (mg/dL)',
                hint: 'Enter blood glucose result',
                min: 1,
                max: 1000,
                name: 'blood glucose level',
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E5),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFF5E0B7),
                  ),
                ),
                child: const Text(
                  'The result is generated by a trained machine-learning '
                  'model. It is not a diagnosis and cannot replace '
                  'professional medical advice.',
                  style: TextStyle(
                    color: Color(0xFF775820),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitPrediction,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    _isLoading
                        ? 'Analyzing...'
                        : 'Check Diabetes Risk',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _primaryBlue.withValues(alpha: 0.65),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}