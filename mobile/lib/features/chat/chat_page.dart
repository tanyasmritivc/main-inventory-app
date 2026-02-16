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

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: 0.72);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double dot(double phase) {
          final v = (t + phase) % 1.0;
          return 0.35 + (0.65 * (1.0 - (2.0 * (v - 0.5)).abs()));
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: dot(0.0), color: base),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.2), color: base),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.4), color: base),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
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

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      final t = error.type;
      if (t == dio.DioExceptionType.connectionTimeout ||
          t == dio.DioExceptionType.sendTimeout ||
          t == dio.DioExceptionType.receiveTimeout) {
        return 'That took longer than expected. Try again.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _sentFirstMessage = true;
      _messages.add(_ChatMessage(role: _Role.user, text: q));
      _messages.add(_ChatMessage(role: _Role.assistant, text: 'One moment…'));
    });
    _controller.clear();

    try {
      final out = await widget.api.aiCommand(message: q);
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'One moment…') {
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
            if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'One moment…') {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e2))));
        }
      } else if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } finally {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == _Role.assistant && _messages.last.text == 'One moment…') {
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
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final muted = Colors.white.withValues(alpha: 0.55);
    final hideSuggestions = _focusNode.hasFocus || _sentFirstMessage;
    const surface = AppColors.surface;
    const accent = AppColors.accentPurple;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assist'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, isIOS ? 18 : 20, 20, 20),
        child: Column(
          children: [
            SizedBox(height: isIOS ? 4 : 8),
            Text(
              'FindEZ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.2,
                    fontSize: isIOS ? 24 : null,
                  ),
            ),
            SizedBox(height: isIOS ? 4 : 6),
            Text(
              'Find anything in seconds.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: isIOS ? 1.25 : null,
                  ),
            ),
            SizedBox(height: isIOS ? 16 : 18),
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
              SizedBox(height: isIOS ? 8 : 10),
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
                        isIOS: isIOS,
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: isIOS ? 12 : 14),
            ],
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start by searching for an item.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(top: isIOS ? 8 : 10, bottom: isIOS ? 8 : 10),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final align = m.role == _Role.user ? Alignment.centerRight : Alignment.centerLeft;
                        final isUser = m.role == _Role.user;
                        final isTyping = !isUser && m.text == 'One moment…';
                        return Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isUser
                                    ? accent.withValues(alpha: 0.14)
                                    : (isTyping
                                        ? surface.withValues(alpha: 0.80)
                                        : AppColors.surface2.withValues(alpha: 0.88)),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isIOS ? 14 : 14,
                                  vertical: isIOS ? 11 : 12,
                                ),
                                child: isTyping
                                    ? const _TypingDots()
                                    : Text(
                                        m.text,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: isUser ? 0.92 : 0.82),
                                          height: isIOS ? 1.2 : 1.25,
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
                        hintText: 'Search your stuff…',
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
                      height: isIOS ? 46 : 44,
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
  const _SuggestionChip({required this.label, required this.onTap, required this.isIOS});

  final String label;
  final VoidCallback onTap;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isIOS ? AppColors.surface.withValues(alpha: 0.52) : AppColors.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}
