import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
"""
Privacy Policy
Last Updated: March 2026

FindEZ respects your privacy and is committed to protecting your personal data.

Information We Collect
We collect information necessary to provide our services including:
• Account information such as email address
• Inventory data you create
• Uploaded images and documents
• Usage data to improve the service

How We Use Your Information
Your information is used to:
• Provide inventory management features
• Enable AI-powered assistance
• Improve and maintain the service
• Respond to support requests

Storage and Security
Your data is stored securely using industry-standard cloud infrastructure. We take reasonable measures to protect your information from unauthorized access.

AI Processing
Images, documents, and messages may be processed by AI services to provide features such as:
• Item extraction from images
• Document summarization
• AI assistant responses

These services process the data only to provide functionality.

Data Ownership
You retain ownership of the data you upload. You may request deletion of your account and associated data at any time.

Account Deletion
To delete your account and all associated data, email:

vinodrexfms@ai-robots.co

from your registered email address.

Changes
We may update this Privacy Policy periodically. Continued use of the app constitutes acceptance of any updates.

Contact
For questions regarding privacy contact:

vinodrexfms@ai-robots.co
"""
          ),
        ),
      ),
    );
  }
}
