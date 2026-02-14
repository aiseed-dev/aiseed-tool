import 'package:flutter_test/flutter_test.dart';
import 'package:grow_cowork/models/message.dart';

void main() {
  group('Message', () {
    test('toMap and fromMap roundtrip', () {
      final msg = Message(
        id: 'test-id',
        conversationId: 'conv-1',
        role: MessageRole.user,
        content: 'Hello',
      );

      final map = msg.toMap();
      final restored = Message.fromMap(map);

      expect(restored.id, msg.id);
      expect(restored.conversationId, msg.conversationId);
      expect(restored.role, msg.role);
      expect(restored.content, msg.content);
    });

    test('toApiMessage returns role and content', () {
      final msg = Message(
        conversationId: 'conv-1',
        role: MessageRole.assistant,
        content: 'Hi there',
      );

      final apiMsg = msg.toApiMessage();
      expect(apiMsg['role'], 'assistant');
      expect(apiMsg['content'], 'Hi there');
    });
  });

  group('Conversation', () {
    test('toMap and fromMap roundtrip', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Test conversation',
        systemPrompt: 'You are helpful',
      );

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.id, conv.id);
      expect(restored.title, conv.title);
      expect(restored.systemPrompt, conv.systemPrompt);
    });

    test('copyWith updates fields', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Original',
      );

      final updated = conv.copyWith(title: 'Updated');
      expect(updated.id, conv.id);
      expect(updated.title, 'Updated');
    });
  });
}
