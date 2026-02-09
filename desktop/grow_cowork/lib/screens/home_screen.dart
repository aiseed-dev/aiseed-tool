import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/settings_service.dart';
import '../services/conversation_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'conversation_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final ConversationService conversationService;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.conversationService,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Conversation? _currentConversation;
  bool _showConversationList = true;

  void _onConversationSelected(Conversation conversation) {
    setState(() {
      _currentConversation = conversation;
      // On narrow screens, hide the list when a conversation is selected
      if (MediaQuery.of(context).size.width < 800) {
        _showConversationList = false;
      }
    });
  }

  void _onNewConversation() {
    final conversation = Conversation(
      title: '新しい会話',
      systemPrompt: widget.settings.systemPrompt,
    );
    widget.conversationService.saveConversation(conversation);
    setState(() {
      _currentConversation = conversation;
      if (MediaQuery.of(context).size.width < 800) {
        _showConversationList = false;
      }
    });
  }

  void _onConversationUpdated(Conversation conversation) {
    widget.conversationService.saveConversation(conversation);
    setState(() {
      _currentConversation = conversation;
    });
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
    setState(() {}); // Refresh after settings change
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    if (!widget.settings.isApiConfigured) {
      return _buildSetupScreen();
    }

    if (isWide) {
      return _buildWideLayout();
    } else {
      return _buildNarrowLayout();
    }
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Grow Cowork',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI栽培コワーカー',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Anthropic APIキーを設定して始めましょう。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('設定を開く'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: ConversationListScreen(
              conversationService: widget.conversationService,
              currentConversationId: _currentConversation?.id,
              onConversationSelected: _onConversationSelected,
              onNewConversation: _onNewConversation,
              onOpenSettings: _openSettings,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _currentConversation != null
                ? ChatScreen(
                    key: ValueKey(_currentConversation!.id),
                    conversation: _currentConversation!,
                    settings: widget.settings,
                    onConversationUpdated: _onConversationUpdated,
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    if (_showConversationList || _currentConversation == null) {
      return Scaffold(
        body: ConversationListScreen(
          conversationService: widget.conversationService,
          currentConversationId: _currentConversation?.id,
          onConversationSelected: _onConversationSelected,
          onNewConversation: _onNewConversation,
          onOpenSettings: _openSettings,
        ),
      );
    }

    return Scaffold(
      body: ChatScreen(
        key: ValueKey(_currentConversation!.id),
        conversation: _currentConversation!,
        settings: widget.settings,
        onConversationUpdated: _onConversationUpdated,
        onBack: () => setState(() => _showConversationList = true),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '会話を選択するか、新しい会話を始めましょう',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
