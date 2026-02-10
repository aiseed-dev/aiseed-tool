import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

class ChatConversationService {
  Directory? _dir;

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final appDir = await getApplicationDocumentsDirectory();
    _dir = Directory('${appDir.path}/grow_chat');
    if (!_dir!.existsSync()) {
      _dir!.createSync(recursive: true);
    }
    return _dir!;
  }

  Future<List<ChatConversation>> listConversations() async {
    final dir = await _getDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    final result = <ChatConversation>[];
    for (final file in files) {
      try {
        final json = jsonDecode(file.readAsStringSync());
        result.add(ChatConversation.fromMap(json as Map<String, dynamic>));
      } catch (_) {}
    }
    return result;
  }

  Future<void> saveConversation(ChatConversation conversation) async {
    final dir = await _getDir();
    final file = File('${dir.path}/${conversation.id}.json');
    file.writeAsStringSync(jsonEncode(conversation.toMap()));
  }

  Future<void> deleteConversation(String id) async {
    final dir = await _getDir();
    final file = File('${dir.path}/$id.json');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
