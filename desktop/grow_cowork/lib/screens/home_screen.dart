import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/settings_service.dart';
import '../services/conversation_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'conversation_list_screen.dart';
import 'weather_screen.dart';

enum NavDestination { chat, weather }

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
  NavDestination _destination = NavDestination.chat;

  void _onConversationSelected(Conversation conversation) {
    setState(() {
      _currentConversation = conversation;
      _destination = NavDestination.chat;
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
      _destination = NavDestination.chat;
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
    setState(() {});
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
          // Left sidebar
          SizedBox(
            width: 300,
            child: Column(
              children: [
                // Nav buttons
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _navButton(Icons.chat, 'Cowork', NavDestination.chat),
                      const SizedBox(width: 4),
                      _navButton(Icons.cloud, '気象', NavDestination.weather),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_destination == NavDestination.chat)
                  Expanded(
                    child: ConversationListScreen(
                      conversationService: widget.conversationService,
                      currentConversationId: _currentConversation?.id,
                      onConversationSelected: _onConversationSelected,
                      onNewConversation: _onNewConversation,
                      onOpenSettings: _openSettings,
                    ),
                  )
                else
                  Expanded(child: _buildWeatherSideInfo()),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Main content
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: _buildMainContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (i) {
          setState(() {
            _destination = NavDestination.values[i];
            _showConversationList = true;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat), label: 'Cowork'),
          NavigationDestination(icon: Icon(Icons.cloud), label: '気象'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_destination) {
      case NavDestination.chat:
        if (!_showConversationList &&
            _currentConversation != null &&
            MediaQuery.of(context).size.width < 800) {
          return ChatScreen(
            key: ValueKey(_currentConversation!.id),
            conversation: _currentConversation!,
            settings: widget.settings,
            onConversationUpdated: _onConversationUpdated,
            onBack: () => setState(() => _showConversationList = true),
          );
        }
        if (MediaQuery.of(context).size.width < 800) {
          return ConversationListScreen(
            conversationService: widget.conversationService,
            currentConversationId: _currentConversation?.id,
            onConversationSelected: _onConversationSelected,
            onNewConversation: _onNewConversation,
            onOpenSettings: _openSettings,
          );
        }
        if (_currentConversation != null) {
          return ChatScreen(
            key: ValueKey(_currentConversation!.id),
            conversation: _currentConversation!,
            settings: widget.settings,
            onConversationUpdated: _onConversationUpdated,
          );
        }
        return _buildEmptyState();

      case NavDestination.weather:
        return WeatherScreen(settings: widget.settings);
    }
  }

  Widget _buildWeatherSideInfo() {
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
              Icon(Icons.cloud,
                  color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('気象データ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                onPressed: _openSettings,
                tooltip: '設定',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _infoTile(Icons.thermostat, 'WS90', '屋外センサー観測値'),
              _infoTile(Icons.location_city, 'アメダス', '気象庁観測データ'),
              _infoTile(Icons.wb_sunny, 'ECMWF', '地温・土壌水分予報'),
              const SizedBox(height: 16),
              Text(
                '右パネルでタブを切り替えて\n各データを表示します',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _navButton(IconData icon, String label, NavDestination dest) {
    final isSelected = _destination == dest;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: isSelected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _destination = dest),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
