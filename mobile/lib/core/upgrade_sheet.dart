import 'package:flutter/material.dart';
import 'api_client.dart';
import 'app_theme.dart';

Future<void> showUpgradeSheet(
  BuildContext context,
  ApiClient api, {
  String? reason,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LimitSheet(api: api, reason: reason),
  );
}

Future<bool> showJoinTeamDialog(BuildContext context, ApiClient api) async {
  return await _showJoinCodeDialog(context, api) ?? false;
}

class _LimitSheet extends StatelessWidget {
  final ApiClient api;
  final String? reason;
  const _LimitSheet({required this.api, this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1AF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Free limit reached',
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (reason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AF59E0B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33F59E0B)),
              ),
              child: Text(
                reason!,
                style: const TextStyle(
                    color: Color(0xFFF59E0B), fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.group_outlined,
                      color: Color(0xFFA78BFA), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'FindEZ Team',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'FindEZ Team covers your whole robotics team — learn more at findez.ai',
                  style: TextStyle(
                    color: AppTheme.textMuted(context),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final joined =
                  await _showJoinCodeDialog(context, api);
              if (joined == true && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFA78BFA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Join a team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: TextStyle(
                    color: AppTheme.textMuted(context), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _showJoinCodeDialog(BuildContext context, ApiClient api) {
  final ctrl = TextEditingController();
  return showDialog<bool>(
    context: context,
    builder: (dlgCtx) {
      String? errorMsg;
      bool loading = false;
      return StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Join a team',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, letterSpacing: 5),
                decoration: const InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  counterStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0x33FFFFFF)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFA78BFA)),
                  ),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 6),
                Text(
                  errorMsg!,
                  style: const TextStyle(
                      color: Color(0xFFFF453A), fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  loading ? null : () => Navigator.pop(dlgCtx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0x73FFFFFF))),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = ctrl.text.trim().toUpperCase();
                      if (code.length != 6) {
                        setState(() => errorMsg = 'Enter a 6-character code.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        errorMsg = null;
                      });
                      try {
                        await api.joinTeam(code);
                        if (dlgCtx.mounted) Navigator.pop(dlgCtx, true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Joined! Your team plan is now active.'),
                              backgroundColor: Color(0xFF30D158),
                            ),
                          );
                        }
                      } catch (_) {
                        setState(() {
                          loading = false;
                          errorMsg = 'Invalid code. Check with your coach.';
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFA78BFA),
                      ),
                    )
                  : const Text('Join',
                      style: TextStyle(
                          color: Color(0xFFA78BFA),
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    },
  ).then((result) {
    ctrl.dispose();
    return result;
  });
}
