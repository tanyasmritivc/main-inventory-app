import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui/app_text.dart';

const legalTermsVersion = '2026-10-18';

enum LegalDocumentKind { privacy, terms }

Uri legalDocumentUrl(LegalDocumentKind document) => Uri.https(
  'findez.ai',
  document == LegalDocumentKind.privacy ? '/privacy' : '/terms',
);

/// Opens the public canonical document; no embedded duplicate can become stale.
class LegalLinkPage extends StatefulWidget {
  const LegalLinkPage({super.key, required this.document, this.openUrl});
  final LegalDocumentKind document;
  final Future<bool> Function(Uri)? openUrl;

  @override
  State<LegalLinkPage> createState() => _LegalLinkPageState();
}

class _LegalLinkPageState extends State<LegalLinkPage> {
  bool _opening = false;
  String? _error;
  String get _title => widget.document == LegalDocumentKind.privacy
      ? 'Privacy Policy'
      : 'Terms of Service';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final url = legalDocumentUrl(widget.document);
      final opened =
          await (widget.openUrl?.call(url) ??
              launchUrl(url, mode: LaunchMode.externalApplication));
      if (!mounted) return;
      if (opened) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else {
        setState(
          () => _error =
              'The browser could not open this page. Try again or copy the link.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The browser could not open this page. Try again or copy the link.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(_title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('Read the current $_title on findez.ai.'),
            const SizedBox(height: 12),
            SelectableText(legalDocumentUrl(widget.document).toString()),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppText(_error!),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: _opening ? null : _open,
              child: AppText(_opening ? 'Opening browser...' : 'Open $_title'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: legalDocumentUrl(widget.document).toString(),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AppText('Link copied.')),
                  );
                }
              },
              child: const AppText('Copy link'),
            ),
          ],
        ),
      ),
    ),
  );
}
