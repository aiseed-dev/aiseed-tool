import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class ConversationService {
  late Directory _dataDir;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${appDir.path}/grow_cowork/conversations');
    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }
  }

  Future<List<Conversation>> listConversations() async {
    final conversations = <Conversation>[];
    await for (final entity in _dataDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await entity.readAsString());
          final messages = (data['messages'] as List?)
                  ?.map((m) => Message.fromMap(m as Map<String, dynamic>))
                  .toList() ??
              [];
          conversations
              .add(Conversation.fromMap(data as Map<String, dynamic>, messages));
        } catch (_) {
          // Skip corrupted files
        }
      }
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  Future<Conversation?> loadConversation(String id) async {
    final file = File('${_dataDir.path}/$id.json');
    if (!await file.exists()) return null;

    final data = jsonDecode(await file.readAsString());
    final messages = (data['messages'] as List?)
            ?.map((m) => Message.fromMap(m as Map<String, dynamic>))
            .toList() ??
        [];
    return Conversation.fromMap(data as Map<String, dynamic>, messages);
  }

  Future<void> saveConversation(Conversation conversation) async {
    final file = File('${_dataDir.path}/${conversation.id}.json');
    final data = conversation.toMap();
    data['messages'] = conversation.messages.map((m) => m.toMap()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> deleteConversation(String id) async {
    final file = File('${_dataDir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
