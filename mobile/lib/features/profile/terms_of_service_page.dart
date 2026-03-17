import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms of Service")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
"""
Terms of Service
Last Updated: March 2026

By using FindEZ you agree to these Terms.

Service Description
FindEZ provides tools to help users track personal inventory, store related documents, and interact with an AI assistant.

User Responsibilities
You agree to:
• Provide accurate account information
• Use the service only for lawful purposes
• Not attempt to disrupt or misuse the system

User Content
You retain ownership of the content you upload including:
• Inventory items
• Images
• Documents

You grant FindEZ permission to process this content solely to provide service functionality.

AI Features
FindEZ uses AI systems to provide features such as:
• Item recognition from images
• Inventory assistance
• Document analysis

AI-generated outputs may not always be accurate and should be verified when necessary.

Service Availability
We may modify or discontinue features at any time. We do not guarantee uninterrupted availability of the service.

Limitation of Liability
FindEZ is provided "as is" without warranties. We are not liable for losses arising from use of the application.

Account Termination
We reserve the right to suspend or terminate accounts that violate these terms.

Account Deletion
Users may request account deletion and removal of associated data by emailing:

vinodrexfms@ai-robots.co

from the registered email address.

Changes to Terms
We may update these Terms periodically. Continued use of the service constitutes acceptance of the updated terms.

Contact
Questions regarding these Terms can be sent to:

vinodrexfms@ai-robots.co
"""
          ),
        ),
      ),
    );
  }
}
