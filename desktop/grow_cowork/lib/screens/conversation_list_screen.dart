import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/conversation_service.dart';

class ConversationListScreen extends StatefulWidget {
  final ConversationService conversationService;
  final String? currentConversationId;
  final ValueChanged<Conversation> onConversationSelected;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenOnboarding;

  const ConversationListScreen({
    super.key,
    required this.conversationService,
    this.currentConversationId,
    required this.onConversationSelected,
    required this.onNewConversation,
    required this.onOpenSettings,
    this.onOpenOnboarding,
  });

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ConversationListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentConversationId != widget.currentConversationId) {
      _load();
    }
  }

  Future<void> _load() async {
    final conversations = await widget.conversationService.listConversations();
    if (mounted) {
      setState(() => _conversations = conversations);
    }
  }

  Future<void> _deleteConversation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会話を削除'),
        content: const Text('この会話を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.conversationService.deleteConversation(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.eco, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Grow Cowork',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (widget.onOpenOnboarding != null)
                IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  onPressed: widget.onOpenOnboarding,
                  tooltip: 'AI設定をつくる',
                ),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                onPressed: widget.onOpenSettings,
                tooltip: '設定',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新しい会話'),
            ),
          ),
        ),
        Expanded(
          child: _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '会話がありません',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        if (widget.onOpenOnboarding != null) ...[
                          const SizedBox(height: 20),
                          FilledButton.tonalIcon(
                            onPressed: widget.onOpenOnboarding,
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text('あなた専用のAI設定をつくる'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isSelected =
                        conv.id == widget.currentConversationId;
                    final messageCount = conv.messages.length;
                    final lastMessage = conv.messages.isNotEmpty
                        ? conv.messages.last.content
                        : '';
                    final preview = lastMessage.length > 60
                        ? '${lastMessage.substring(0, 60)}...'
                        : lastMessage;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      title: Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: preview.isNotEmpty
                          ? Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Text(
                        '$messageCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      onTap: () => widget.onConversationSelected(conv),
                      onLongPress: () => _deleteConversation(conv.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
