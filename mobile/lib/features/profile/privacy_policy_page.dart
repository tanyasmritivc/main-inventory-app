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

FindEZ (“we”, “our”, or “us”) respects your privacy and is committed to protecting your information. This Privacy Policy explains what data we collect, how we use it, and your rights.

1. Information We Collect

We collect information necessary to provide and improve the app, including:

• Account Information: such as your email address  
• User Content: items you add to inventory, messages you send, and any data you input  
• Uploaded Data: images or documents you choose to upload  
• Usage Data: basic app usage information (e.g., feature usage, interactions)

2. How We Use Your Information

We use your information to:

• Provide inventory management functionality  
• Enable AI-powered assistance  
• Process and respond to your requests  
• Improve and maintain the app  
• Provide customer support  

We do not sell your personal data to third parties.

3. AI and Third-Party Processing

To provide AI features, some data (such as messages, images, or documents) may be processed by third-party services, including OpenAI.

These services process data solely to provide functionality and are not permitted to use your data for unrelated purposes.

4. Data Storage and Security

Your data is stored using secure cloud infrastructure. We take reasonable measures to protect your information from unauthorized access, loss, or misuse.

However, no system can be completely secure, and we cannot guarantee absolute security.

5. Data Retention

We retain your data only as long as necessary to provide the app’s functionality or comply with legal obligations.

6. Your Rights

You have the right to:

• Access your data  
• Request correction of your data  
• Request deletion of your data  

7. Account Deletion

You may request deletion of your account and associated data by contacting:

vinodrexfms@ai-robots.co

Requests will be processed within a reasonable timeframe.

8. Children’s Privacy

FindEZ is not intended for children under 13, and we do not knowingly collect personal data from children.

9. Changes to This Policy

We may update this Privacy Policy from time to time. Continued use of the app constitutes acceptance of any updates.

10. Contact

If you have any questions about this Privacy Policy, contact:

vinodrexfms@ai-robots.co
"""
          ),
        ),
      ),
    );
  }
}
