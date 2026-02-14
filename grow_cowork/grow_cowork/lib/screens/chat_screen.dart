import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../services/settings_service.dart';
import '../services/claude_service.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final SettingsService settings;
  final ValueChanged<Conversation> onConversationUpdated;
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.settings,
    required this.onConversationUpdated,
    this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  late List<Message> _messages;
  bool _isLoading = false;
  String _streamingContent = '';
  late ClaudeService _claude;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.conversation.messages);
    _claude = ClaudeService(
      apiKey: widget.settings.apiKey,
      model: widget.settings.model,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

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

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();

    final userMessage = Message(
      conversationId: widget.conversation.id,
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _streamingContent = '';
    });
    _scrollToBottom();

    // Auto-title from first message
    var title = widget.conversation.title;
    if (_messages.where((m) => m.role == MessageRole.user).length == 1) {
      title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
    }

    try {
      final buffer = StringBuffer();

      await for (final chunk in _claude.sendMessageStream(
        messages: _messages,
        systemPrompt: widget.conversation.systemPrompt,
      )) {
        buffer.write(chunk);
        setState(() {
          _streamingContent = buffer.toString();
        });
        _scrollToBottom();
      }

      final assistantMessage = Message(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: buffer.toString(),
      );

      setState(() {
        _messages.add(assistantMessage);
        _streamingContent = '';
        _isLoading = false;
      });

      final updated = widget.conversation.copyWith(
        title: title,
        updatedAt: DateTime.now(),
        messages: _messages,
      );
      widget.onConversationUpdated(updated);
    } on ClaudeApiException catch (e) {
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

    _inputFocusNode.requestFocus();
    _scrollToBottom();
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コピーしました'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: _showConversationInfo,
                tooltip: '会話情報',
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty && !_isLoading
              ? _buildWelcome()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount:
                      _messages.length + (_streamingContent.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      return _buildMessageBubble(_messages[index]);
                    } else {
                      // Streaming message
                      return _buildStreamingBubble();
                    }
                  },
                ),
        ),

        // Loading indicator
        if (_isLoading && _streamingContent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          ),

        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                    }
                  },
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力... (Enter送信 / Shift+Enter改行)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Coworkを始めましょう',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('今の季節に植えられる野菜は？'),
                _buildSuggestionChip('トマトのコンパニオンプランツを教えて'),
                _buildSuggestionChip('来月の栽培計画を一緒に考えよう'),
                _buildSuggestionChip('土壌改良のアドバイスをください'),
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
      onPressed: () {
        _inputController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == MessageRole.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.eco, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onSecondaryTap: () => _copyMessage(message.content),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(maxWidth: 700),
                child: isUser
                    ? SelectableText(message.content)
                    : MarkdownBody(
                        data: message.content,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(Uri.parse(href));
                          }
                        },
                      ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.tertiaryContainer,
              child:
                  Icon(Icons.person, size: 18, color: colorScheme.tertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.eco, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(maxWidth: 700),
              child: MarkdownBody(
                data: '$_streamingContent ▍',
                selectable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConversationInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会話情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('メッセージ数: ${_messages.length}'),
            const SizedBox(height: 8),
            Text('作成: ${widget.conversation.createdAt.toString().substring(0, 16)}'),
            const SizedBox(height: 8),
            Text('モデル: ${widget.settings.model}'),
            const SizedBox(height: 8),
            Text('システムプロンプト:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.conversation.systemPrompt ?? '(なし)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
