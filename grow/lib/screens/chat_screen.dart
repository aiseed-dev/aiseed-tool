import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_conversation_service.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';

const kAiSystemPromptPref = 'ai_system_prompt';

class ChatScreen extends StatefulWidget {
  final ChatConversationService conversationService;
  final VoidCallback? onOpenSettings;

  const ChatScreen({
    super.key,
    required this.conversationService,
    this.onOpenSettings,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatConversation> _conversations = [];
  ChatConversation? _current;
  bool _isLoading = false;
  String _streamingContent = '';

  // AI settings
  AiProvider _provider = AiProvider.fastapi;
  String _apiKey = '';
  String _model = '';
  String _systemPrompt = '';
  String _serverUrl = '';
  String _serverToken = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadConversations();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final providerIndex = prefs.getInt(kAiProviderPref) ?? 0;
      _provider = AiProvider
          .values[providerIndex.clamp(0, AiProvider.values.length - 1)];
      _apiKey = prefs.getString(kAiApiKeyPref) ?? '';
      _model = prefs.getString(kAiModelPref) ?? '';
      _serverUrl = prefs.getString(kServerUrlPref) ?? '';
      _serverToken = prefs.getString(kServerTokenPref) ?? '';
      _systemPrompt = prefs.getString(kAiSystemPromptPref) ??
          prefs.getString(kSkillFileKey) ??
          '';
    });
  }

  Future<void> _loadConversations() async {
    final list = await widget.conversationService.listConversations();
    if (!mounted) return;
    setState(() => _conversations = list);
  }

  bool get _isConfigured {
    if (_provider == AiProvider.fastapi) {
      return _serverUrl.isNotEmpty;
    }
    return _apiKey.isNotEmpty;
  }

  AiChatService _createService() => AiChatService(
        provider: _provider,
        apiKey: _apiKey,
        model: _model.isNotEmpty ? _model : null,
        serverUrl: _serverUrl,
        serverToken: _serverToken,
      );

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newConversation() {
    final conv = ChatConversation(
      title: '新しい会話',
      systemPrompt: _systemPrompt.isNotEmpty ? _systemPrompt : null,
    );
    widget.conversationService.saveConversation(conv);
    setState(() {
      _current = conv;
      _conversations.insert(0, conv);
    });
  }

  void _selectConversation(ChatConversation conv) {
    setState(() => _current = conv);
  }

  Future<void> _deleteConversation(ChatConversation conv) async {
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
    if (confirmed != true) return;
    await widget.conversationService.deleteConversation(conv.id);
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
      if (_current?.id == conv.id) _current = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Auto-create conversation
    if (_current == null) {
      _newConversation();
    }

    _inputController.clear();

    final userMsg = ChatMessage(
      conversationId: _current!.id,
      role: ChatRole.user,
      content: text,
    );

    final messages = [..._current!.messages, userMsg];
    var title = _current!.title;
    if (messages.where((m) => m.role == ChatRole.user).length == 1) {
      title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
    }

    setState(() {
      _current = _current!.copyWith(messages: messages);
      _isLoading = true;
      _streamingContent = '';
    });
    _scrollToBottom();

    try {
      final service = _createService();
      final buffer = StringBuffer();

      await for (final chunk in service.sendMessageStream(
        messages: messages,
        systemPrompt: _current!.systemPrompt,
      )) {
        buffer.write(chunk);
        setState(() => _streamingContent = buffer.toString());
        _scrollToBottom();
      }

      final assistantMsg = ChatMessage(
        conversationId: _current!.id,
        role: ChatRole.assistant,
        content: buffer.toString(),
      );

      final updated = _current!.copyWith(
        title: title,
        updatedAt: DateTime.now(),
        messages: [...messages, assistantMsg],
      );

      setState(() {
        _current = updated;
        _streamingContent = '';
        _isLoading = false;
        final idx = _conversations.indexWhere((c) => c.id == updated.id);
        if (idx >= 0) _conversations[idx] = updated;
      });

      widget.conversationService.saveConversation(updated);
    } on AiChatException catch (e) {
      setState(() {
        _isLoading = false;
        _streamingContent = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _streamingContent = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (_current != null) {
      return _buildChatView();
    }
    return _buildListView();
  }

  // ── Conversation list ──

  Widget _buildListView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.eco, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('AI Cowork',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (!_isConfigured)
                Icon(Icons.warning_amber,
                    color: Theme.of(context).colorScheme.error, size: 20),
              if (widget.onOpenSettings != null)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () async {
                    widget.onOpenSettings!();
                    // Reload settings when coming back
                    await Future.delayed(const Duration(milliseconds: 300));
                    _loadSettings();
                  },
                  tooltip: '設定',
                ),
            ],
          ),
        ),

        // New conversation button
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConfigured ? _newConversation : _showApiKeyHint,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新しい会話'),
            ),
          ),
        ),

        // Conversations list
        Expanded(
          child: _conversations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final count = conv.messages.length;
                    final preview = conv.messages.isNotEmpty
                        ? conv.messages.last.content
                        : '';
                    final previewText = preview.length > 60
                        ? '${preview.substring(0, 60)}...'
                        : preview;
                    return ListTile(
                      title: Text(conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: previewText.isNotEmpty
                          ? Text(previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))
                          : null,
                      trailing: Text('$count',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      onTap: () => _selectConversation(conv),
                      onLongPress: () => _deleteConversation(conv),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _isConfigured ? '会話を始めましょう' : 'サーバーURLを設定してください',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (!_isConfigured) ...[
              const SizedBox(height: 8),
              Text(
                _provider == AiProvider.fastapi
                    ? '設定 → サーバーURL を入力（APIキー不要）'
                    : '設定 → AIプロバイダーからAPIキーを入力',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('今の季節に植えられる野菜は？'),
                _buildSuggestionChip('トマトの育て方を教えて'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 13)),
      onPressed: _isConfigured
          ? () {
              _inputController.text = text;
              _sendMessage();
            }
          : null,
    );
  }

  // ── Chat view ──

  Widget _buildChatView() {
    final cs = Theme.of(context).colorScheme;
    final messages = _current!.messages;

    return Column(
      children: [
        // Header with back
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _current = null),
              ),
              Expanded(
                child: Text(
                  _current!.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _provider == AiProvider.fastapi
                    ? 'Server'
                    : _provider == AiProvider.gemini
                        ? 'Gemini'
                        : 'Claude',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messages.isEmpty && !_isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco,
                          size: 48,
                          color: cs.primary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('質問してみましょう',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length +
                      (_streamingContent.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return _buildBubble(messages[index]);
                    }
                    return _buildStreamingBubble();
                  },
                ),
        ),

        // Loading
        if (_isLoading && _streamingContent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: LinearProgressIndicator(),
          ),

        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.eco, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('コピーしました'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUser
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isUser
                    ? Text(message.content)
                    : MarkdownBody(
                        data: message.content,
                        onTapLink: (_, href, __) {
                          if (href != null) launchUrl(Uri.parse(href));
                        },
                      ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.eco, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownBody(data: '$_streamingContent ▍'),
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyHint() {
    final msg = _provider == AiProvider.fastapi
        ? '設定 → サーバーURL を入力してください（APIキー不要）'
        : '設定 → AIプロバイダー からAPIキーを入力してください';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
