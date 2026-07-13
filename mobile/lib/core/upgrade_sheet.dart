import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

Future<void> showUpgradeSheet(
  BuildContext context,
  ApiClient api, {
  String? reason,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UpgradeSheet(api: api, reason: reason),
  );
}

class _UpgradeSheet extends StatefulWidget {
  final ApiClient api;
  final String? reason;
  const _UpgradeSheet({required this.api, this.reason});
  @override
  State<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<_UpgradeSheet> {
  bool _loading = false;

  Future<void> _subscribe(String plan) async {
    setState(() => _loading = true);
    try {
      final url = await widget.api.createCheckoutSession(plan: plan);
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1A4B8BF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: Color(0xFF4B8BF5), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'FindEZ Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (widget.reason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AEF4444),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33EF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.reason!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Features
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Column(
              children: [
                _FeatureRow('Unlimited items & spaces'),
                _FeatureRow('Unlimited AI photo scans'),
                _FeatureRow('Share spaces with anyone'),
                _FeatureRow('Spreadsheet import'),
                _FeatureRow('Priority support'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Pricing buttons
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF4B8BF5)))
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _subscribe('monthly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B8BF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            '\$6.99',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'per month',
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _subscribe('yearly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4B8BF5)),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            '\$59.99',
                            style: TextStyle(
                              color: Color(0xFF4B8BF5),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'per year',
                            style: TextStyle(
                              color: Color(0x804B8BF5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x0A4B8BF5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                '✦ Save 28% with annual plan',
                style: TextStyle(
                  color: Color(0x664B8BF5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Maybe later',
                style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF4B8BF5), size: 15),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
        ],
      ),
    );
  }
}
