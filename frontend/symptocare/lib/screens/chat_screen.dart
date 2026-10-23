
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'chat_history_store.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;

  // Optional first message, for example a diabetes assessment.
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  late ChatConversation _conversation;

  static const String _baseUrl = 'http://127.0.0.1:8000';

  late final String _backendConversationId;

  List<Map<String, String>> get _messages =>
      _conversation.messages;

  PlatformFile? _selectedFile;
  bool _isSending = false;

  static const int _maxFileSize = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();

    final existing = widget.conversationId == null
        ? null
        : ChatHistoryStore.findConversation(
            widget.conversationId!,
          );

    _conversation =
        existing ?? ChatHistoryStore.createConversation();

    _backendConversationId =
        widget.conversationId ?? _conversation.id;

    if (existing != null) {
      _loadSavedMessages();
    } else {
      final initialMessage = widget.initialMessage?.trim();

      if (initialMessage != null && initialMessage.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // Save the new conversation before sending its first message.
          await _saveNewConversation();

          if (!mounted) return;

          _messageController.text = initialMessage;
          await _sendMessage();
        });
      } else {
        _saveNewConversation();
      }
    }
  }

  Future<void> _loadSavedMessages() async {
    try {
      await ChatHistoryStore.loadMessages(_conversation);

      if (!mounted) return;

      setState(() {});
      _scrollToBottom();
    } catch (e) {
      debugPrint('Could not load saved messages: $e');
    }
  }

  Future<void> _saveNewConversation() async {
    try {
      await ChatHistoryStore.saveConversation(_conversation);

      for (final message in _conversation.messages) {
        await ChatHistoryStore.saveMessage(
          _conversation.id,
          message,
        );
      }
    } catch (e) {
      debugPrint('Could not save new conversation: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.size > _maxFileSize) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select a file smaller than 10 MB.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedFile = file;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select file: $e'),
        ),
      );
    }
  }

  void _removeDocument() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final attachment = _selectedFile;

    if ((text.isEmpty && attachment == null) || _isSending) {
      return;
    }

    final messageText = text.isEmpty
        ? 'Please review my attached medical report.'
        : text;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': messageText,
      });

      if (attachment != null) {
        _messages.add({
          'role': 'user_file',
          'text': attachment.name,
        });
      }

      _messageController.clear();
      _selectedFile = null;
      _isSending = true;
    });

    ChatHistoryStore.refreshConversation(_conversation);

    debugPrint('CHAT DEBUG: Starting Firebase save');

    try {
      await ChatHistoryStore.saveConversation(_conversation);

      for (final message in _messages.reversed
          .take(attachment != null ? 2 : 1)
          .toList()
          .reversed) {
        await ChatHistoryStore.saveMessage(
          _conversation.id,
          message,
        );
      }
    } catch (e) {
      debugPrint('Could not save user message: $e');
    }

    _scrollToBottom();

    debugPrint('CHAT DEBUG: Firebase save finished');

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please sign in to use the health assistant.');
      }

      final idToken = await user.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not verify your sign-in. Please sign in again.');
      }

      late http.Response response;

      
      if (attachment != null) {
        // Upload the report and message together.
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/chat/with-report'),
        );

        request.headers['Authorization'] = 'Bearer $idToken';

        request.fields['message'] = messageText;
        request.fields['conversation_id'] = _backendConversationId;

        request.fields['conversation_id'] =
            _backendConversationId;

        final bytes = attachment.bytes;

        if (bytes == null) {
          throw Exception('Could not read the selected file.');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: attachment.name,
          ),
        );

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 120),
        );

        response = await http.Response.fromStream(
          streamedResponse,
        );
      } else {
        // Send a normal chat message.
        response = await http
            .post(
              Uri.parse('$_baseUrl/chat'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              body: jsonEncode({
                'message': messageText,
                'conversation_id': _backendConversationId,
                'medical_values': <String, dynamic>{},
              }),
            )
            .timeout(const Duration(seconds: 120));
      }

      debugPrint(
        'CHAT DEBUG: Sending HTTP request to $_baseUrl/chat',
      );
      debugPrint('CHAT STATUS: ${response.statusCode}');
      debugPrint('CHAT BODY: ${response.body}');      

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Server returned ${response.statusCode}: '
          '${response.body}',
        );
      }

      dynamic result = response.body;

      // FastAPI may return a JSON-encoded string.
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        // The response was plain text; use it as-is.
      }

      String reply;

      if (result is String) {
        try {
          final decoded = jsonDecode(result);

          if (decoded is Map<String, dynamic>) {
            reply = (decoded['assistant_message'] ??
                    decoded['response'] ??
                    decoded['reply'] ??
                    decoded['answer'] ??
                    decoded['message'])
                ?.toString() ??
                result;
          } else {
            reply = result;
          }
        } catch (_) {
          reply = result;
        }
      } else if (result is Map<String, dynamic>) {
        reply = (result['assistant_message'] ??
                result['response'] ??
                result['reply'] ??
                result['answer'] ??
                result['message'])
            ?.toString() ??
            response.body;
      } else {
        reply = response.body;
      }

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': reply,
        });
      });

      try {
        await ChatHistoryStore.saveMessage(
          _conversation.id,
          _messages.last,
        );

        ChatHistoryStore.refreshConversation(_conversation);
        await ChatHistoryStore.saveConversation(_conversation);
      } catch (e) {
        debugPrint('Could not save assistant reply: $e');
      }
    } catch (e) {
      debugPrint('CHAT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text':
              'Sorry, I couldn’t process your message right now. '
              'Please try again in a moment.',
        });
      });

      try {
        await ChatHistoryStore.saveMessage(
          _conversation.id,
          _messages.last,
        );

        ChatHistoryStore.refreshConversation(_conversation);
        await ChatHistoryStore.saveConversation(_conversation);
      } catch (saveError) {
        debugPrint(
          'Could not save error message: $saveError',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });

        ChatHistoryStore.refreshConversation(_conversation);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.primaryBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const SymptoCareLogo(size: 30),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SymptoCare',
                    style: TextStyle(
                      color: Color(0xFF202B45),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Health Assistant',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == _messages.length) {
                    return _buildTypingIndicator();
                  }

                  final message = _messages[index];
                  final role = message['role']!;
                  final isUser = role == 'user';
                  final isFile = role == 'user_file';

                  if (isFile) {
                    return _buildFileMessage(message['text']!);
                  }

                  return _buildMessageBubble(
                    message['text']!,
                    isUser: isUser,
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    String text, {
    required bool isUser,
  }) {
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width *
              (isUser ? 0.80 : 0.94),
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: const Color(0xFFE9EDF5),
                ),
        ),
        child: isUser
            ? Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              )
            : MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Color(0xFF28334D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: const TextStyle(
                    color: Color(0xFF28334D),
                    fontWeight: FontWeight.w600,
                  ),
                  h1: const TextStyle(
                    color: Color(0xFF202B45),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    color: Color(0xFF202B45),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    color: Color(0xFF202B45),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF28334D),
                    fontSize: 14,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFileMessage(String filename) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD4E1FF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              color: AppTheme.primaryBlue,
              size: 28,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                filename,
                style: const TextStyle(
                  color: Color(0xFF28334D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 24,
          height: 18,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFile != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(_selectedFile!.size / 1024).toStringAsFixed(0)} KB · Ready to attach',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removeDocument,
                    tooltip: 'Remove attachment',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _isSending ? null : _pickDocument,
                tooltip: 'Attach medical report',
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: AppTheme.primaryBlue,
                  size: 27,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  tooltip: 'Send message',
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'SymptoCare provides health-risk insights, not a diagnosis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
