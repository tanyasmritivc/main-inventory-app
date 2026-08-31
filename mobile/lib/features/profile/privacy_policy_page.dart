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
Effective: August 30, 2026

AI Robots Inc (“AI Robots,” “FindEZ,” “we,” “us,” or “our”) provides FindEZ. This Policy explains what information FindEZ collects, why we use it, when it is disclosed, and the choices available to you.

1. Scope

This Policy applies to the FindEZ mobile app, website, APIs, and related services. It does not govern third-party websites or services that have their own privacy notices.

2. Information We Collect

• Account and profile data, including email address, display name, authentication provider, account identifiers, and team role.
• Inventory and workspace content, including Spaces, items, quantities, locations, barcodes, part numbers, notes, tags, Project Kits, Team Board entries, documents, and shopping or readiness information.
• Content you submit for processing, including photos, camera captures, spreadsheets, documents, voice-search input, AI prompts, and feedback.
• Collaboration data, including teams and shared Spaces you create or join, invite codes, permissions, assignments, member activity, and notifications.
• Technical and usage data, such as device and app information, IP address, timestamps, feature interactions, error and security logs, and push-notification tokens.
• Information from Apple, Google, or another sign-in provider when you choose that method, subject to your provider settings.
• Camera, photo-library, microphone, speech-recognition, notification, or location information only when you choose a feature requiring it and grant the relevant device permission. FindEZ does not require these optional permissions for unrelated features.

We collect this information directly from you, automatically when you use FindEZ, from collaborators in your Teams or shared Spaces, and from providers you choose to connect.

3. How We Use Information

We use information to operate and secure FindEZ; authenticate accounts; store, search, scan, organize, and share inventory; provide Teams, reminders, activity history, and notifications; process support requests and service messages; prevent abuse; troubleshoot and improve reliability; enforce our Terms; and comply with law.

We use submitted prompts, images, and documents to provide requested AI and extraction features. AI output can be inaccurate and should be reviewed before it is saved or relied upon.

Confirmed, non-personal product facts—such as a manufacturer, part number, or barcode—may be separated from account identifiers and used to improve FindEZ’s shared product catalog. We do not publicly expose your private inventory, quantities, locations, notes, images, or documents for that purpose.

4. When Information Is Disclosed

• Other users: content and activity are visible according to the Team or shared-Space permissions you choose. Owners and managers may manage membership and access. Leaving or losing access does not delete content owned by another user.
• Service providers: we use providers for hosting, database, authentication, storage, AI processing (including OpenAI), email delivery, push notifications, sign-in, security, and support. They may process information only to perform services for us and must protect it consistently with their agreements and applicable law.
• Legal and safety reasons: we may disclose information when reasonably necessary to comply with law, protect rights or safety, investigate abuse, or secure the Service.
• Business transfers: information may be transferred as part of a merger, financing, acquisition, reorganization, bankruptcy, or sale of assets, subject to this Policy or notice of materially different practices.

We do not sell personal information. We do not share personal information for cross-context behavioral advertising, and we do not use third-party advertising trackers in FindEZ.

5. AI Processing

When you use an AI feature, the content needed to answer the request may be sent to an AI provider. Do not submit information you are not authorized to disclose. FindEZ uses business/API services; provider handling and limited security or abuse-monitoring retention may apply under the provider’s terms. We do not permit AI providers to use FindEZ API content to train general models unless we give notice and obtain any consent required by law.

6. Retention and Deletion

We retain account data and user content while your account is active and as needed to provide the Service. Bell-notification history is ordinarily available for 14 days. Operational logs, fraud-prevention records, backups, and transaction records may remain for a limited period after deletion when reasonably necessary for security, dispute resolution, legal compliance, or backup rotation.

You can permanently delete your account in Account Settings. Deletion removes the account and associated data controlled by FindEZ, subject to legal and technical retention described above. Content owned by another user or organization remains with that owner; shared copies or exports made by other users are outside our control. You may also contact us for assistance.

You can revoke device permissions in iOS Settings, disable notifications, leave joined Spaces or Teams, remove members, stop sharing a Space, or reset a Team invite code. Revoking permission may disable the related feature.

7. Security and International Processing

We use reasonable administrative, technical, and organizational safeguards. No method of storage or transmission is completely secure. Information may be processed where we or our providers operate, which may be outside your state or country and subject to appropriate legal protections where required.

8. Your Privacy Choices and Rights

Depending on where you live, you may have rights to request access, correction, deletion, or a portable copy of personal information; object to or restrict certain processing; withdraw consent; or appeal a denied request. We will not discriminate against you for exercising applicable rights. We may verify your identity before completing a request. Authorized agents may submit requests where permitted by law.

Because FindEZ does not sell personal information or share it for cross-context behavioral advertising, FindEZ does not offer a “Do Not Sell or Share” opt-out. If our practices change, we will update this Policy and provide required choices.

9. Children and Student Users

Individual account holders must be at least 13 years old. If you are under the age of legal majority where you live, use FindEZ only with permission and supervision from a parent, legal guardian, school, or authorized team adult. FindEZ is not directed to children under 13, and they may not create their own accounts. Schools and organizations are responsible for obtaining any permissions required before inviting students or submitting student information. Contact us if you believe a child under 13 provided personal information without proper authorization.

10. Changes

We may update this Policy as FindEZ changes. We will post the revised effective date and provide additional notice when required. Material changes apply prospectively unless law permits otherwise.

11. Contact

For privacy questions or requests, contact AI Robots Inc at:
vinodrexfms@ai-robots.co
"""
          ),
        ),
      ),
    );
  }
}
