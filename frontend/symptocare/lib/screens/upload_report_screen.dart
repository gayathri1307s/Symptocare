
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'report_analysis_screen.dart';

class UploadReportScreen extends StatefulWidget {
  const UploadReportScreen({super.key});

  @override
  State<UploadReportScreen> createState() =>
      _UploadReportScreenState();
}

class _UploadReportScreenState extends State<UploadReportScreen> {
  PlatformFile? _selectedFile;
  bool _isPicking = false;

  static const int _maxFileSize = 10 * 1024 * 1024;

  Future<void> _pickReport() async {
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;

      if (file.size > _maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a report smaller than 10 MB.'),
          ),
        );
        setState(() => _isPicking = false);
        return;
      }

      setState(() {
        _selectedFile = file;
        _isPicking = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isPicking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select report: $e')),
      );
    }
  }

  void _removeReport() {
    setState(() => _selectedFile = null);
  }


  void _continueToAnalysis() {
    final file = _selectedFile;
    if (file == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportAnalysisScreen(
          fileName: file.name,
          fileSizeBytes: file.size,
          fileBytes: file.bytes,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.primaryBlue,
          ),
        ),
        title: const Row(
          children: [
            SymptoCareLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'Upload Report',
              style: TextStyle(
                color: Color(0xFF202B45),
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Your health reports, in one place.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF202B45),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a medical report to prepare it for review '
              'in SymptoCare.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 24),

            // File selection area
            InkWell(
              onTap: _isPicking ? null : _pickReport,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFCAD8FA),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 76,
                      width: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: _isPicking
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.cloud_upload_outlined,
                              size: 42,
                              color: AppTheme.primaryBlue,
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isPicking
                          ? 'Opening files...'
                          : 'Choose a medical report',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202B45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PDF or image (JPG, JPEG, PNG)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Maximum file size: 10 MB',
                      style: TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isPicking ? null : _pickReport,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Browse files'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: const BorderSide(
                          color: AppTheme.primaryBlue,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedFile != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Selected report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202B45),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE3EAF7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 34,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${(_selectedFile!.size / 1024).toStringAsFixed(0)} KB',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _removeReport,
                      tooltip: 'Remove report',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _continueToAnalysis,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Continue to Report Analysis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

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
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your report is only selected locally at this stage. '
                      'It has not been uploaded to a server or analysed.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF344563),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
