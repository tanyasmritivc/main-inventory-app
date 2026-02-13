import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  final _suggestions = const [
    'Find my receipts',
    "What’s low stock?",
    'Summarize my last upload',
    'Show items I should restock',
  ];

  bool _sending = false;
  final List<_ChatMessage> _messages = [];
  bool _sentFirstMessage = false;

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _sentFirstMessage = true;
      _messages.add(_ChatMessage(role: _Role.user, text: q));
      _messages.add(_ChatMessage(role: _Role.assistant, text: 'AI is typing…'));
    });
    _controller.clear();

    try {
      final out = await widget.api.aiCommand(message: q);
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'AI is typing…') {
          _messages.removeLast();
        }
        _messages.add(
          _ChatMessage(
            role: _Role.assistant,
            text: out.assistantMessage.isEmpty ? 'Done.' : out.assistantMessage,
          ),
        );
      });
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;

      if (!mounted) return;
      if (status == 404) {
        try {
          final res = await widget.api.searchItems(query: q);
          if (!mounted) return;
          setState(() {
            if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'AI is typing…') {
              _messages.removeLast();
            }
            _messages.add(
              _ChatMessage(
                role: _Role.assistant,
                text: res.items.isEmpty
                    ? 'No matches found.'
                    : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
              ),
            );
          });
        } catch (e2) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e2.toString())));
        }
      } else if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'AI is typing…') {
            _messages.removeLast();
          }
        });
      }
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.55);
    final hideSuggestions = _focusNode.hasFocus || _sentFirstMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assist'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'FindEZ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask anything about your stuff.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 18),
            if (!hideSuggestions) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _suggestions
                    .map(
                      (s) => _SuggestionChip(
                        label: s,
                        onTap: () {
                          _submit(s);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Ask a question to get started.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final align = m.role == _Role.user ? Alignment.centerRight : Alignment.centerLeft;
                        final isUser = m.role == _Role.user;
                        return Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.accentPurple.withValues(alpha: 0.14) : AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Text(
                                  m.text,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: isUser ? 0.92 : 0.82),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            GlassCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 20,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Attach',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything about your stuff…',
                        isDense: true,
                      ),
                      onSubmitted: (v) => _submit(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: PrimaryGradientButton(
                      onPressed: _sending ? null : () => _submit(_controller.text),
                      height: 44,
                      borderRadius: 999,
                      child: Text(_sending ? '…' : 'Send'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Role { user, assistant }

class _ChatMessage {
  _ChatMessage({required this.role, required this.text});

  final _Role role;
  final String text;
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
