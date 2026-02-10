import 'package:uuid/uuid.dart';

enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    String? id,
    required this.conversationId,
    required this.role,
    required this.content,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        role: ChatRole.values.firstWhere((e) => e.name == map['role']),
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ChatConversation {
  final String id;
  final String title;
  final String? systemPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatConversation({
    String? id,
    required this.title,
    this.systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  ChatConversation copyWith({
    String? title,
    String? systemPrompt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) =>
      ChatConversation(
        id: id,
        title: title ?? this.title,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'system_prompt': systemPrompt,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    final msgs = (map['messages'] as List?)
            ?.map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList() ??
        [];
    return ChatConversation(
      id: map['id'] as String,
      title: map['title'] as String,
      systemPrompt: map['system_prompt'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      messages: msgs,
    );
  }
}
