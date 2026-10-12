import 'package:flutter/material.dart';
import '../../core/legal_links.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const LegalLinkPage(document: LegalDocumentKind.terms);
}
