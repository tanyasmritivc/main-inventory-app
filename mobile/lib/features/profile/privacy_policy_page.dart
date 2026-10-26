import 'package:flutter/material.dart';
import '../../core/legal_links.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const LegalLinkPage(document: LegalDocumentKind.privacy);
}
