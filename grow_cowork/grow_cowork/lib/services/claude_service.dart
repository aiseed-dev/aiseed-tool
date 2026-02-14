import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ClaudeService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _defaultModel = 'claude-sonnet-4-5-20250929';
  static const String _apiVersion = '2023-06-01';

  final String apiKey;
  final String model;

  ClaudeService({
    required this.apiKey,
    this.model = _defaultModel,
  });

  bool get isConfigured => apiKey.isNotEmpty;

  Future<String> sendMessage({
    required List<Message> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) async {
    if (!isConfigured) {
      throw Exception('API key is not configured');
    }

    final apiMessages = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => m.toApiMessage())
        .toList();

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': apiMessages,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage =
          error['error']?['message'] ?? 'Unknown error (${response.statusCode})';
      throw ClaudeApiException(errorMessage, response.statusCode);
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    if (content.isEmpty) {
      return '';
    }

    final textBlocks = content
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .toList();

    return textBlocks.join('\n');
  }

  Stream<String> sendMessageStream({
    required List<Message> messages,
    String? systemPrompt,
    int maxTokens = 4096,
  }) async* {
    if (!isConfigured) {
      throw Exception('API key is not configured');
    }

    final apiMessages = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => m.toApiMessage())
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

    final request = http.Request('POST', Uri.parse(_apiUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': _apiVersion,
    });
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final responseBody =
            await streamedResponse.stream.bytesToString();
        final error = jsonDecode(responseBody);
        final errorMessage = error['error']?['message'] ??
            'Unknown error (${streamedResponse.statusCode})';
        throw ClaudeApiException(
            errorMessage, streamedResponse.statusCode);
      }

      final lineBuffer = StringBuffer();

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final lines = lineBuffer.toString().split('\n');
        lineBuffer.clear();

        // Keep the last incomplete line in the buffer
        if (!chunk.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) {
            continue;
          }

          final data = trimmed.substring(6);
          if (data == '[DONE]') {
            return;
          }

          try {
            final event = jsonDecode(data);
            final type = event['type'] as String?;

            if (type == 'content_block_delta') {
              final delta = event['delta'];
              if (delta != null && delta['type'] == 'text_delta') {
                yield delta['text'] as String;
              }
            } else if (type == 'error') {
              final errorMessage =
                  event['error']?['message'] ?? 'Stream error';
              throw ClaudeApiException(errorMessage, 0);
            }
          } catch (e) {
            if (e is ClaudeApiException) rethrow;
            // Skip malformed JSON lines
          }
        }
      }
    } finally {
      client.close();
    }
  }
}

class ClaudeApiException implements Exception {
  final String message;
  final int statusCode;

  ClaudeApiException(this.message, this.statusCode);

  @override
  String toString() => 'ClaudeApiException($statusCode): $message';
}
