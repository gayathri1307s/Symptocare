
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'chat_screen.dart';
import 'chat_history_store.dart';

class ChatHistoryScreen extends StatefulWidget {
const ChatHistoryScreen({super.key});

@override
State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
final TextEditingController _searchController =
TextEditingController();

List<ChatConversation> _conversations = [];
bool _isLoading = true;
String? _loadError;
String _searchQuery = '';

static const Color navy = Color(0xFF202B45);
static const Color background = Color(0xFFF6F8FD);
static const Color borderColor = Color(0xFFE7ECF5);

@override
void initState() {
super.initState();
_loadConversations();
}

Future<void> _loadConversations() async {
if (mounted) {
setState(() {
_isLoading = true;
_loadError = null;
});
}

try {
final conversations =
await ChatHistoryStore.loadConversations();

if (!mounted) return;

setState(() {
_conversations = conversations;
_isLoading = false;
_loadError = null;
});
} catch (e) {
debugPrint('Could not load chat history: $e');

if (!mounted) return;

setState(() {
_isLoading = false;
_loadError = 'Could not load your conversations.';
});
}
}

List<ChatConversation> get _filteredConversations {
if (_searchQuery.trim().isEmpty) {
return _conversations;
}

final query = _searchQuery.trim().toLowerCase();

return _conversations.where((conversation) {
return conversation.title.toLowerCase().contains(query) ||
conversation.preview.toLowerCase().contains(query) ||
conversation.category.toLowerCase().contains(query);
}).toList();
}

void _openConversation(ChatConversation conversation) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ChatScreen(
conversationId: conversation.id,
),
),
).then((_) {
if (mounted) {
_loadConversations();
}
});
}

void _showDeleteConfirmation(ChatConversation conversation) {
showDialog<void>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Remove conversation?'),
content: const Text(
'This will remove the conversation and its saved messages.',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext);
},
child: const Text('Cancel'),
),
TextButton(
onPressed: () async {
Navigator.pop(dialogContext);

try {
await ChatHistoryStore.deleteConversation(
conversation.id,
);

if (!mounted) return;

setState(() {
_conversations.removeWhere(
(item) => item.id == conversation.id,
);
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Conversation removed.'),
),
);
} catch (e) {
debugPrint(
'Could not delete conversation: $e',
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Could not remove the conversation.',
),
),
);
}
},
child: const Text(
'Remove',
style: TextStyle(color: Colors.redAccent),
),
),
],
);
},
);
}

void _startNewChat() {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const ChatScreen(),
),
).then((_) {
if (mounted) {
_loadConversations();
}
});
}

@override
void dispose() {
_searchController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final conversations = _filteredConversations;

return Scaffold(
backgroundColor: background,
appBar: AppBar(
backgroundColor: Colors.white,
elevation: 0.5,
leading: IconButton(
onPressed: () => Navigator.maybePop(context),
icon: const Icon(
Icons.arrow_back_rounded,
color: AppTheme.primaryBlue,
),
),
title: Row(
children: [
const SymptoCareLogo(size: 32),
const SizedBox(width: 10),
const Expanded(
child: Text(
'Chat History',
style: TextStyle(
color: navy,
fontSize: 19,
fontWeight: FontWeight.bold,
),
),
),
IconButton(
tooltip: 'New conversation',
onPressed: _startNewChat,
icon: const Icon(
Icons.add_comment_outlined,
color: AppTheme.primaryBlue,
),
),
],
),
),
body: SafeArea(
child: Column(
children: [
Padding(
padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Your conversations',
style: TextStyle(
color: navy,
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 7),
const Text(
'Review your previous health discussions.',
style: TextStyle(
color: AppTheme.textGrey,
fontSize: 13,
height: 1.5,
),
),
const SizedBox(height: 20),
TextField(
controller: _searchController,
onChanged: (value) {
setState(() {
_searchQuery = value;
});
},
decoration: InputDecoration(
hintText: 'Search conversations...',
hintStyle: const TextStyle(
color: AppTheme.textGrey,
fontSize: 13,
),
prefixIcon: const Icon(
Icons.search_rounded,
color: AppTheme.primaryBlue,
),
suffixIcon: _searchQuery.isNotEmpty
? IconButton(
onPressed: () {
_searchController.clear();
setState(() {
_searchQuery = '';
});
},
icon: const Icon(
Icons.close_rounded,
),
)
    : null,
filled: true,
fillColor: Colors.white,
contentPadding:
const EdgeInsets.symmetric(vertical: 14),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(15),
borderSide: const BorderSide(
color: borderColor,
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(15),
borderSide: const BorderSide(
color: borderColor,
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(15),
borderSide: const BorderSide(
color: AppTheme.primaryBlue,
width: 1.5,
),
),
),
),
const SizedBox(height: 20),
Row(
children: [
const Expanded(
child: Text(
'Recent chats',
style: TextStyle(
color: navy,
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
Text(
'${conversations.length} conversations',
style: const TextStyle(
color: AppTheme.textGrey,
fontSize: 11,
),
),
],
),
],
),
),
Expanded(
child: _isLoading
? const Center(
child: CircularProgressIndicator(),
)
    : _loadError != null
? Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.cloud_off_outlined,
size: 42,
color: AppTheme.textGrey,
),
const SizedBox(height: 12),
Text(
_loadError!,
textAlign: TextAlign.center,
),
const SizedBox(height: 12),
ElevatedButton(
onPressed: _loadConversations,
child: const Text('Try again'),
),
],
),
),
)
    : conversations.isEmpty
? _buildEmptyState()
    : ListView.separated(
padding: const EdgeInsets.fromLTRB(
20, 8, 20, 20,
),
itemCount: conversations.length,
separatorBuilder: (_, _) =>
const SizedBox(height: 12),
itemBuilder: (context, index) {
final conversation =
conversations[index];

return _buildConversationCard(
conversation,
);
},
),
),
Container(
padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
decoration: BoxDecoration(
color: Colors.white,
border: Border(
top: BorderSide(
color: Colors.grey.shade200,
),
),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.shield_outlined,
color: AppTheme.primaryBlue,
size: 17,
),
SizedBox(width: 7),
Flexible(
child: Text(
'Your health matters. Chat responsibly.',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textGrey,
fontSize: 11,
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

Widget _buildConversationCard(
ChatConversation conversation,
) {
final category = conversation.category;

final Color iconColor;
final Color iconBackground;
final IconData iconData;

switch (category) {
case 'Report':
iconColor = AppTheme.primaryBlue;
iconBackground = const Color(0xFFEAF1FF);
iconData = Icons.description_outlined;
break;
case 'Symptoms':
iconColor = const Color(0xFFD98625);
iconBackground = const Color(0xFFFFF3E5);
iconData = Icons.favorite_border_rounded;
break;
default:
iconColor = const Color(0xFF239B68);
iconBackground = const Color(0xFFE4F7ED);
iconData = Icons.chat_bubble_outline_rounded;
}

return Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(17),
border: Border.all(color: borderColor),
),
child: InkWell(
onTap: () => _openConversation(conversation),
borderRadius: BorderRadius.circular(17),
child: Padding(
padding: const EdgeInsets.all(14),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
height: 46,
width: 46,
decoration: BoxDecoration(
color: iconBackground,
borderRadius: BorderRadius.circular(13),
),
child: Icon(
iconData,
color: iconColor,
size: 23,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
conversation.title,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: navy,
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 6),
Text(
conversation.preview,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: AppTheme.textGrey,
fontSize: 12,
height: 1.4,
),
),
const SizedBox(height: 8),
Text(
ChatHistoryStore.formatDate(
conversation.updatedAt,
),
style: const TextStyle(
color: Color(0xFF8A95A8),
fontSize: 10,
),
),
],
),
),
PopupMenuButton<String>(
tooltip: 'Conversation options',
padding: EdgeInsets.zero,
icon: const Icon(
Icons.more_vert_rounded,
color: AppTheme.textGrey,
),
onSelected: (value) {
if (value == 'delete') {
_showDeleteConfirmation(conversation);
}
},
itemBuilder: (_) => const [
PopupMenuItem<String>(
value: 'delete',
child: Row(
children: [
Icon(
Icons.delete_outline_rounded,
color: Colors.redAccent,
size: 20,
),
SizedBox(width: 9),
Text('Remove'),
],
),
),
],
),
],
),
),
),
);
}

Widget _buildEmptyState() {
return Center(
child: Padding(
padding: const EdgeInsets.all(30),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
height: 90,
width: 90,
decoration: const BoxDecoration(
color: Color(0xFFEAF1FF),
shape: BoxShape.circle,
),
child: const Icon(
Icons.chat_bubble_outline_rounded,
color: AppTheme.primaryBlue,
size: 42,
),
),
const SizedBox(height: 20),
Text(
_searchQuery.isNotEmpty
? 'No conversations found'
    : 'No chats yet',
style: const TextStyle(
color: navy,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
Text(
_searchQuery.isNotEmpty
? 'Try searching with another keyword.'
    : 'Start a conversation with SymptoCare '
'to see it listed here.',
textAlign: TextAlign.center,
style: const TextStyle(
color: AppTheme.textGrey,
fontSize: 13,
height: 1.5,
),
),
if (_searchQuery.isEmpty) ...[
const SizedBox(height: 20),
ElevatedButton.icon(
onPressed: _startNewChat,
icon: const Icon(Icons.add_comment_outlined),
label: const Text('Start New Chat'),
),
],
],
),
),
);
}
}
