
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReportAnalysisScreen extends StatefulWidget {
  final String fileName;
  final int fileSizeBytes;
  final Uint8List? fileBytes;

  const ReportAnalysisScreen({
    super.key,
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileBytes,
  });

  @override
  State<ReportAnalysisScreen> createState() =>
      _ReportAnalysisScreenState();
}

class _ReportAnalysisScreenState extends State<ReportAnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportResult;

  late final AnimationController _animationController;

  // This address works on an Android device when ADB reverse is enabled.
  static const String _baseUrl = 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _analyzeReport();
  }

  Future<void> _analyzeReport() async {
    if (widget.fileBytes == null || widget.fileBytes!.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage =
        'The selected file could not be read. Please select it again.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _reportResult = null;
    });

    _animationController.repeat();

    try {
      final uri = Uri.parse('$_baseUrl/reports/extract');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          widget.fileBytes!,
          filename: widget.fileName,
        ),
      );

      final streamedResponse =
      await request.send().timeout(
        const Duration(seconds: 120),
      );

      final response =
      await http.Response.fromStream(streamedResponse);

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception(
          'The server returned an invalid response. Please try again.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'The server returned an unexpected response.',
        );
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final detail = decoded['detail'];

        throw Exception(
          detail is String
              ? detail
              : 'Report extraction failed. Please try again.',
        );
      }

      if (decoded['status'] != 'success') {
        throw Exception(
          'The report could not be processed successfully.',
        );
      }

      if (!mounted) return;

      setState(() {
        _reportResult = decoded;
        _isAnalyzing = false;
      });

      _animationController.stop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ClientException: ', '');
      });

      _animationController.stop();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
    )
        .split(' ')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }

  Widget _buildFileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatFileSize(widget.fileSizeBytes),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: _animationController,
            child: const Icon(
              Icons.health_and_safety_outlined,
              size: 64,
              color: Color(0xFF23845D),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analyzing Your Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF205C45),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Uploading your file and extracting available medical values. '
                'This may take a moment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(
            color: Color(0xFF23845D),
            backgroundColor: Color(0xFFD7EBDD),
          ),
          const SizedBox(height: 12),
          Text(
            'Please keep this screen open.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 42,
            color: Colors.red.shade700,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to Analyze Report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An unexpected error occurred.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _analyzeReport,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23845D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedValues() {
    final rawValues = _reportResult?['medical_values'];

    final values = rawValues is Map
        ? Map<String, dynamic>.from(rawValues)
        : <String, dynamic>{};

    final extractedText = _reportResult?['extracted_text'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF23845D),
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Extraction Completed',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF205C45),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The system has finished processing the file. '
                          'Review the values below.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Extracted Medical Values',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          values.isEmpty
              ? 'No supported medical values were identified in this report.'
              : 'These values were extracted from your uploaded report.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 14),
        if (values.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Try a clearer report with readable text and visible '
                  'test results. Not every test name or value is supported.',
              style: TextStyle(height: 1.5),
            ),
          )
        else
          ...values.entries.map((entry) {
            final value = entry.value;

            String displayValue;

            if (value is Map) {
              final parts = <String>[];

              for (final item in value.entries) {
                if (item.value != null &&
                    item.value.toString().trim().isNotEmpty) {
                  parts.add(
                    '${_formatLabel(item.key.toString())}: '
                        '${item.value}',
                  );
                }
              }

              displayValue =
              parts.isEmpty ? 'Not available' : parts.join('\n');
            } else {
              displayValue = value?.toString() ?? 'Not available';
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    color: Color(0xFF23845D),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayValue,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        if (extractedText is String &&
            extractedText.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'View Extracted Report Text',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  extractedText,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Important: Extracted values may be incomplete or '
                      'incorrect. Check them against the original report. '
                      'This extraction is not a diagnosis and does not '
                      'indicate your disease risk.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text(
          'Report Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF205C45),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your Medical Report',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF205C45),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your uploaded file and the values identified by '
                  'SymptoCare.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            _buildFileCard(),
            const SizedBox(height: 24),
            if (_isAnalyzing)
              _buildLoadingSection()
            else if (_errorMessage != null)
              _buildErrorSection()
            else if (_reportResult != null)
                _buildExtractedValues(),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Upload'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF23845D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
