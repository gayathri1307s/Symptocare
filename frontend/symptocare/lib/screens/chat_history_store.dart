
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.title = 'New conversation',
    this.preview = 'Start a conversation',
    this.category = 'Health',
  });

  final String id;
  final List<Map<String, String>> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  String title;
  String preview;
  String category;

  factory ChatConversation.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return ChatConversation(
      id: id,
      title: data['title'] as String? ?? 'New conversation',
      preview: data['preview'] as String? ?? 'Start a conversation',
      category: data['category'] as String? ?? 'Health',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      messages: [],
    );
  }
}

class ChatHistoryStore {
  static final List<ChatConversation> conversations = [];

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static int _nextId = 0;

  static String? get _userId =>
      FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>
  get _sessions {
    final uid = _userId;
    if (uid == null) {
      throw StateError('Please sign in to access chat history.');
    }

    return _db.collection('users').doc(uid).collection(
      'chatSessions',
    );
  }

  static ChatConversation createConversation() {
    final now = DateTime.now();

    final conversation = ChatConversation(
      id: 'chat_${now.microsecondsSinceEpoch}_${_nextId++}',
      createdAt: now,
      updatedAt: now,
      messages: [
        {
          'role': 'assistant',
          'text':
          'Hi! Welcome to SymptoCare. 💙\n\n'
              'Tell me how you are feeling today. You can also attach '
              'a medical report for review once report analysis is connected.',
        },
      ],
    );

    conversations.insert(0, conversation);
    return conversation;
  }

  static ChatConversation? findConversation(String id) {
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  static Future<void> saveConversation(
      ChatConversation conversation,
      ) async {
    await _sessions.doc(conversation.id).set({
      'title': conversation.title,
      'preview': conversation.preview,
      'category': conversation.category,
      'createdAt': Timestamp.fromDate(conversation.createdAt),
      'updatedAt': Timestamp.fromDate(conversation.updatedAt),
    }, SetOptions(merge: true));
  }

  static Future<void> saveMessage(
      String conversationId,
      Map<String, String> message,
      ) async {
    final role = message['role'];
    final messageText = message['text'] ?? '';

    if (!['user', 'assistant', 'user_file'].contains(role)) {
      throw ArgumentError('Invalid message role.');
    }

    if (messageText.length > 10000) {
      throw ArgumentError('Message is too long to save.');
    }

    await _sessions
        .doc(conversationId)
        .collection('messages')
        .add({
      'role': role,
      'text': messageText,
      'createdAt': Timestamp.now(),
    });
  }

  static Future<List<ChatConversation>> loadConversations() async {
    final snapshot = await _sessions
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return ChatConversation.fromFirestore(
        doc.id,
        doc.data(),
      );
    }).toList();
  }

  static Future<void> loadMessages(
      ChatConversation conversation,
      ) async {
    final snapshot = await _sessions
        .doc(conversation.id)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    conversation.messages
      ..clear()
      ..addAll(snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'role': data['role'] as String? ?? 'assistant',
          'text': data['text'] as String? ?? '',
        };
      }));
  }

  static Future<void> deleteConversation(
      String conversationId,
      ) async {
    final session = _sessions.doc(conversationId);
    final messages = await session.collection('messages').get();

    final batch = _db.batch();

    for (final message in messages.docs) {
      batch.delete(message.reference);
    }

    batch.delete(session);
    await batch.commit();

    conversations.removeWhere(
          (conversation) => conversation.id == conversationId,
    );
  }

  static void refreshConversation(
      ChatConversation conversation,
      ) {
    conversation.updatedAt = DateTime.now();

    final userMessages = conversation.messages.where(
          (message) => message['role'] == 'user',
    );

    if (userMessages.isNotEmpty) {
      final firstMessage = userMessages.first['text'] ?? '';
      conversation.title = firstMessage.length > 35
          ? '${firstMessage.substring(0, 32)}...'
          : firstMessage;

      conversation.preview =
          userMessages.last['text'] ?? '';
    }

    conversations.remove(conversation);
    conversations.insert(0, conversation);
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return 'Today · $hour:$minute $period';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
