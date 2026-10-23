
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class PredictionResultScreen extends StatelessWidget {
  final String diseaseName;
  final String riskLevel;
  final double? probability;
  final List<String> keyFindings;
  final VoidCallback? onChatPressed;
  final Map<String, dynamic>? assessmentValues;
  final int? modelPrediction;
  final double? rawProbability;

  const PredictionResultScreen({
  super.key,
  this.diseaseName = 'Diabetes Risk Assessment',
  this.riskLevel = 'Awaiting Results',
  this.probability,
  this.keyFindings = const [],
  this.onChatPressed,
  this.assessmentValues,
  this.modelPrediction,
  this.rawProbability,
  });

  static const Color primaryBlue = Color(0xFF3860F5);
  static const Color darkBlue = Color(0xFF172B52);
  static const Color pageBackground = Color(0xFFF5F8FD);
  static const Color borderColor = Color(0xFFE5ECF7);

  @override
  Widget build(BuildContext context) {
    final hasResult = probability != null &&
        probability! >= 0 &&
        probability! <= 100;

    final riskColor = riskLevel.toLowerCase().contains('high')
        ? const Color(0xFFE84D65)
        : riskLevel.toLowerCase().contains('moderate')
            ? const Color(0xFFE99A17)
            : riskLevel.toLowerCase().contains('low')
                ? const Color(0xFF10A981)
                : const Color(0xFF65738C);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Analysis Result',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkBlue,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF263D65)
                          .withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: primaryBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              diseaseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: riskColor,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            riskLevel,
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Probability',
                            style: TextStyle(
                              color: Color(0xFF65738C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          hasResult ? '${probability!}%' : 'Unavailable',
                          style: const TextStyle(
                            color: darkBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: hasResult ? probability! / 100 : 0,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEDF1F8),
                        valueColor:
                            const AlwaysStoppedAnimation(primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasResult
                          ? 'Model output: ${probability!}%'
                          : 'No prediction score has been provided.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8793A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Key Findings',
                      style: TextStyle(
                        color: darkBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (keyFindings.isEmpty)
                      const Text(
                        'No findings are available yet. '
                        'Complete an assessment to view supported results.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF65738C),
                          height: 1.5,
                        ),
                      )
                    else
                      ...keyFindings.map(
                        (finding) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: darkBlue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  finding,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF43536D),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FC),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD9EFF8),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF347C9E),
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a screening result, not a diagnosis. '
                        'Please consult a qualified healthcare '
                        'professional for further evaluation.',
                        style: TextStyle(
                          color: Color(0xFF365B70),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onChatPressed ??
                    () {
                      final values = assessmentValues ?? {};

                      final assessmentMessage = '''
                I completed a Diabetes Risk Assessment in SymptoCare.

                My submitted values:
                - Age: ${values['age'] ?? 'Not provided'} years
                - Gender: ${values['gender'] ?? 'Not provided'}
                - Hypertension: ${values['hypertension'] == 1 ? 'Yes' : values['hypertension'] == 0 ? 'No' : 'Not provided'}
                - Heart disease: ${values['heart_disease'] == 1 ? 'Yes' : values['heart_disease'] == 0 ? 'No' : 'Not provided'}
                - Smoking history: ${values['smoking_history'] ?? 'Not provided'}
                - BMI: ${values['bmi'] ?? 'Not provided'}
                - HbA1c: ${values['HbA1c_level'] ?? 'Not provided'}%
                - Blood glucose: ${values['blood_glucose_level'] ?? 'Not provided'} mg/dL

                Model prediction: ${modelPrediction ?? 'Not available'}
                Probability for the positive class: ${rawProbability == null ? 'Not available' : '${(rawProbability! * 100).toStringAsFixed(2)}%'}

                Please explain this result in simple language. Explain that it is a machine-learning screening estimate, not a diagnosis. Help me understand what the measurements generally mean and what I could discuss with a healthcare professional.
                ''';

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            initialMessage: assessmentMessage,
                          ),
                        ),
                      );
                    },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 19,
                  ),
                  label: const Text(
                    'Chat with AI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'SymptoCare supports health awareness and does not '
                  'replace professional medical advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8995A8),
                    fontSize: 11,
                    height: 1.5,
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
