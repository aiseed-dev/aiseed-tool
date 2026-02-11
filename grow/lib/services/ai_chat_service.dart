import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

// SharedPreferences keys for AI settings
const kAiProviderPref = 'ai_provider';
const kAiApiKeyPref = 'ai_api_key';
const kAiModelPref = 'ai_model';

enum AiProvider {
  /// FastAPI サーバー経由（APIキー不要、サーバーが管理）
  fastapi,

  /// Gemini API（直接、APIキー必要）
  gemini,

  /// Claude API（直接、APIキー必要）
  claude,
}

class AiChatException implements Exception {
  final String message;
  final int statusCode;
  AiChatException(this.message, this.statusCode);

  @override
  String toString() => 'AiChatException($statusCode): $message';
}

/// Multi-provider AI chat service (FastAPI / Gemini / Claude)
class AiChatService {
  final AiProvider provider;
  final String apiKey;
  final String model;
  final String? serverUrl;
  final String? serverToken;

  AiChatService({
    required this.provider,
    required this.apiKey,
    String? model,
    this.serverUrl,
    this.serverToken,
  }) : model = model ?? _defaultModel(provider);

  bool get isConfigured {
    if (provider == AiProvider.fastapi) {
      return serverUrl != null && serverUrl!.isNotEmpty;
    }
    return apiKey.isNotEmpty;
  }

  static String _defaultModel(AiProvider provider) {
    switch (provider) {
      case AiProvider.fastapi:
        return ''; // サーバー側のデフォルトを使用
      case AiProvider.gemini:
        return 'gemini-2.0-flash';
      case AiProvider.claude:
        return 'claude-haiku-4-5-20251001';
    }
  }

  static List<(String, String)> modelsFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.fastapi:
        return [
          ('', 'サーバーのデフォルト'),
          ('claude-haiku-4-5-20251001', 'Claude Haiku 4.5'),
          ('claude-sonnet-4-5-20250929', 'Claude Sonnet 4.5'),
        ];
      case AiProvider.gemini:
        return [
          ('gemini-2.0-flash', 'Gemini 2.0 Flash (無料)'),
          ('gemini-1.5-flash', 'Gemini 1.5 Flash (無料)'),
          ('gemini-2.0-flash-lite', 'Gemini 2.0 Flash Lite (無料)'),
        ];
      case AiProvider.claude:
        return [
          ('claude-haiku-4-5-20251001', 'Claude Haiku 4.5'),
          ('claude-sonnet-4-5-20250929', 'Claude Sonnet 4.5'),
        ];
    }
  }

  // ── Streaming entry point ──

  Stream<String> sendMessageStream({
    required List<ChatMessage> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) {
    switch (provider) {
      case AiProvider.fastapi:
        return _fastapiStream(
          messages: messages,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
        );
      case AiProvider.gemini:
        return _geminiStream(
          messages: messages,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
        );
      case AiProvider.claude:
        return _claudeStream(
          messages: messages,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
        );
    }
  }

  // ── FastAPI (server proxy, no API key needed on phone) ──

  Stream<String> _fastapiStream({
    required List<ChatMessage> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) async* {
    if (serverUrl == null || serverUrl!.isEmpty) {
      throw AiChatException('サーバーURLが未設定です', 0);
    }

    final apiUrl = '${serverUrl!}/ai/chat';

    final apiMessages = messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => {
              'role': m.role.name,
              'content': m.content,
            })
        .toList();

    final body = <String, dynamic>{
      'messages': apiMessages,
      'max_tokens': maxTokens,
      'stream': true,
    };

    if (model.isNotEmpty) {
      body['model'] = model;
    }

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final request = http.Request('POST', Uri.parse(apiUrl));
    request.headers['Content-Type'] = 'application/json';
    if (serverToken != null && serverToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $serverToken';
    }
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        String errorMsg;
        try {
          final err = jsonDecode(responseBody);
          errorMsg = err['detail'] ?? 'Server error (${response.statusCode})';
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}';
        }
        throw AiChatException(errorMsg, response.statusCode);
      }

      // Claude streaming format (same as direct Claude API)
      final lineBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final lines = lineBuffer.toString().split('\n');
        lineBuffer.clear();

        if (!chunk.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

          final data = trimmed.substring(6);
          if (data == '[DONE]') return;

          try {
            final event = jsonDecode(data);
            final type = event['type'] as String?;

            if (type == 'content_block_delta') {
              final delta = event['delta'];
              if (delta != null && delta['type'] == 'text_delta') {
                yield delta['text'] as String;
              }
            } else if (type == 'error') {
              final errorMsg =
                  event['error']?['message'] ?? 'Stream error';
              throw AiChatException(errorMsg, 0);
            }
          } catch (e) {
            if (e is AiChatException) rethrow;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Gemini ──

  Stream<String> _geminiStream({
    required List<ChatMessage> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) async* {
    if (!isConfigured) throw AiChatException('API key not set', 0);

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey';

    final contents = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == ChatRole.system) continue;
      contents.add({
        'role': m.role == ChatRole.user ? 'user' : 'model',
        'parts': [
          {'text': m.content}
        ],
      });
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
      },
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        String errorMsg;
        try {
          final err = jsonDecode(responseBody);
          errorMsg = err['error']?['message'] ??
              'Unknown error (${response.statusCode})';
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}';
        }
        throw AiChatException(errorMsg, response.statusCode);
      }

      final lineBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final lines = lineBuffer.toString().split('\n');
        lineBuffer.clear();

        if (!chunk.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

          final data = trimmed.substring(6);
          if (data == '[DONE]') return;

          try {
            final event = jsonDecode(data);
            final candidates = event['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts =
                  candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  yield text;
                }
              }
            }
          } catch (_) {
            // skip malformed
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Claude ──

  Stream<String> _claudeStream({
    required List<ChatMessage> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) async* {
    if (!isConfigured) throw AiChatException('API key not set', 0);

    const apiUrl = 'https://api.anthropic.com/v1/messages';

    final apiMessages = messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => {
              'role': m.role.name,
              'content': m.content,
            })
        .toList();

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': apiMessages,
      'stream': true,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final request = http.Request('POST', Uri.parse(apiUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    });
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        String errorMsg;
        try {
          final err = jsonDecode(responseBody);
          errorMsg = err['error']?['message'] ??
              'Unknown error (${response.statusCode})';
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}';
        }
        throw AiChatException(errorMsg, response.statusCode);
      }

      final lineBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final lines = lineBuffer.toString().split('\n');
        lineBuffer.clear();

        if (!chunk.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

          final data = trimmed.substring(6);
          if (data == '[DONE]') return;

          try {
            final event = jsonDecode(data);
            final type = event['type'] as String?;

            if (type == 'content_block_delta') {
              final delta = event['delta'];
              if (delta != null && delta['type'] == 'text_delta') {
                yield delta['text'] as String;
              }
            } else if (type == 'error') {
              final errorMsg =
                  event['error']?['message'] ?? 'Stream error';
              throw AiChatException(errorMsg, 0);
            }
          } catch (e) {
            if (e is AiChatException) rethrow;
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
