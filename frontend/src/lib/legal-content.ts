import type { LegalSection } from "@/components/site/legal-document";

export const LEGAL_VERSION = "2026-10-18";
export const LEGAL_EFFECTIVE_DATE = "October 18, 2026";
export const PRIVACY_EFFECTIVE_DATE = "October 18, 2026";
export const COOKIE_NOTICE_TEXT = "FindEZ uses cookies for sign-in and saves preferences and drafts on this device. No analytics or advertising cookies are enabled.";

export const privacySections: LegalSection[] = [
  {
    "id": "scope",
    "heading": "1. Who we are and what this covers",
    "body": [
      "AI Robots Inc operates FindEZ. This notice covers the FindEZ website, mobile app, APIs, and related services. It explains our handling of personal information, including information in school and team accounts. Services you connect or visit have their own privacy notices."
    ]
  },
  {
    "id": "information",
    "heading": "2. Information we handle",
    "body": [
      "We receive information from you, people you collaborate with, the sign-in providers you choose, and use of the service."
    ],
    "bullets": [
      "Account and profile information: email, account identifiers, sign-in method, name, optional profile fields, team role, and account eligibility and Terms acknowledgments.",
      "Optional setup answers: your intended use, inventory types, main goal, and whether you work alone or with others. Completed answers are linked to your account after sign-in, are not shared with Team members, and can be updated in Profile.",
      "Setup drafts: the personal or team setup choices and organization, workspace, and inventory names you enter. Drafts can remain on your device before sign-in; completing setup creates the account resources you confirm.",
      "Optional account memory: preferences you explicitly save and private location aliases for an inventory. Settings > Memory lets you review, edit, export, forget, or disable this memory. Disabling memory does not delete your inventory or conversation history.",
      "Workspace content: inventory names, quantities, physical locations you enter, barcodes, part numbers, Spaces, notes, documents, project kits, team tasks, and sharing permissions.",
      "Submitted content: the photos, spreadsheets, prompts, corrections, and other files you choose to upload. Files can include metadata, including location information embedded by the device that created them.",
      "Service information: IP addresses, request and error logs, timestamps, account activity, and device tokens used for phone notifications.",
      "Purchase information: plan and entitlement records. Payment providers handle payment details under their own notices; FindEZ does not need your full card number to provide inventory features."
    ]
  },
  {
    "id": "purposes",
    "heading": "3. Why we use information",
    "body": [
      "We use information to authenticate you; store, search, identify, organize, and share inventory; answer your requests; run team features and notifications; provide support; use optional setup answers to guide setup and improve FindEZ; prevent abuse; diagnose failures; and meet legal obligations.",
      "Where a legal basis is required, we rely on providing the service you request, legitimate interests in security and reliable operation, legal obligations, or consent for an optional activity where required. A device permission does not authorize unrelated uses.",
      "When you confirm non-personal manufacturer facts, such as a barcode and part number, those facts may improve the shared parts catalog. Your private quantities, locations, notes, photos, and documents are not published as catalog entries."
    ]
  },
  {
    "id": "ai",
    "heading": "4. Photos, AI, and voice",
    "body": [
      "FindEZ's FIND vision pipeline and language model inference run on infrastructure operated for FindEZ. In-app AI requests are not sent to OpenAI for hosted inference. The service processes the image, question, and relevant account records needed for the requested answer.",
      "If you connect an external assistant through an API key or connector, that assistant can receive information allowed by the key's permissions. Its provider controls its own processing. You can revoke the key in Settings.",
      "Optional iOS voice input uses Apple's speech-recognition services; audio may be processed by Apple to transcribe it. FindEZ receives the transcription to perform your search or request. Typed input remains available.",
      "AI identifications, quantities, measurements, and inventory matches can be wrong. Review an answer and its source records before saving or acting on it."
    ]
  },
  {
    "id": "sharing",
    "heading": "5. Who can receive information",
    "body": [
      "We do not sell personal information, use advertising trackers, or share personal information for cross-context behavioral advertising. No optional analytics or advertising cookies are enabled.",
      "Authorized collaborators receive the content and activity permitted by organization, workspace, inventory, or shared-Space access. New access invitations require the recipient to accept. Administrative authority and access to inventory contents are separate; restricted inventories and explicit No access settings can limit what an owner or administrator can read. Owners and authorized managers can change membership and roles. Revoking access cannot retrieve copies someone has already exported.",
      "Infrastructure, authentication, email, sign-in, payment, and push-notification providers handle information needed for their services. Apple receives device information needed to deliver iOS notifications. Support correspondence is handled through our contact mailbox. Provider protections and international arrangements must apply where required by law.",
      "We may disclose information to meet a legal obligation, investigate abuse, protect rights or safety, or complete a business transfer. We will provide any notice and choices required by applicable law."
    ]
  },
  {
    "id": "cookies",
    "heading": "6. Cookies and device storage",
    "body": [
      "The website uses authentication cookies to keep you signed in and refresh your session. It also stores the appearance and navigation settings you choose, unfinished Ask and setup drafts, local purchase plans, and temporary sign-up or invitation information needed to finish a requested action. These are used for FindEZ features, not advertising or behavioral tracking.",
      "The cookie notice stores its dismissal for this notice version. Dismissing it acknowledges the information; it is not agreement to Terms or consent to optional tracking.",
      "Sign out to end your account session. Browser controls can remove cookies and site storage, but doing so may sign you out and remove drafts or local purchase plans. Stored preferences and local plans otherwise remain until changed or cleared. Authentication cookie expiry and renewal follow the session configuration.",
      "The mobile app stores login state, selected preferences, and feature caches on the device. Use device or browser settings to manage stored data and permissions. If we introduce optional tracking, we will identify its purpose and providers and provide the required choices before enabling it."
    ]
  },
  {
    "id": "permissions",
    "heading": "7. Permissions and choices",
    "body": [
      "Camera and photo access support the captures and uploads you choose. Microphone and speech recognition support optional voice input. Phone notification permission allows alerts; the in-app team feed remains available without it. FindEZ does not need your device's precise location: inventory locations are names you enter.",
      "You can refuse a permission, revoke it in device settings, use typed input instead of voice, revoke API keys, leave a Team or shared Space, or stop sharing a Space. Refusing one optional permission does not prevent unrelated features."
    ]
  },
  {
    "id": "retention",
    "heading": "8. Retention and account deletion",
    "body": [
      "Account content is kept while needed to provide your account and requested features. The bell feed displays team notifications from the last 14 days; this is a display window, not a promise that underlying team activity is deleted after 14 days.",
      "Delete account in Settings starts permanent deletion of your account and associated records and stored files controlled by FindEZ. If you own a shared workspace or organization, the app can require you to transfer ownership or delete that resource first to protect collaborators. Account removal and stored-file cleanup can finish at different times; a failed deletion request displays an error, and you can retry or contact us for help. Content owned by another account or organization, exported copies, and records that must be retained for legal or security purposes can remain.",
      "Logs, operational backups, and transaction or dispute records may remain when needed for security, recovery, or legal obligations. We do not promise immediate removal from every backup. Contact us about a specific retention or deletion request."
    ]
  },
  {
    "id": "security",
    "heading": "9. Security and international processing",
    "body": [
      "We use access controls and other safeguards, but no service is completely secure. FindEZ-hosted inventory photos require authenticated requests and current permission to the associated content; copying the stored photo URL alone does not grant access. Documents use authenticated access and temporary links. Authorized recipients may still save or export copies. Avoid uploading identity documents or other sensitive personal information to inventory photo features.",
      "Photo processing does not yet use encryption on every network connection. Submit only object images that do not contain confidential or personal information.",
      "We operate from the United States. Information may be processed in countries where our infrastructure or chosen providers operate. Applicable transfer protections and mandatory rights remain relevant; App Store availability does not itself establish compliance in every country."
    ]
  },
  {
    "id": "rights",
    "heading": "10. Privacy requests",
    "body": [
      "Contact info@findez.ai to request access, correction, deletion, a portable copy, or information about our handling of your data. Where applicable, you may object to or restrict processing, withdraw consent, use an authorized agent, appeal a decision, or complain to your data-protection authority. We may request information needed to verify the request, and applicable exceptions can limit a right.",
      "We will respond within the time required by applicable law and will not discriminate against you for exercising applicable rights. Because sale and cross-context advertising sharing are not enabled, there is no such processing to opt out of. If practices change, we will provide required notices and controls."
    ]
  },
  {
    "id": "students",
    "heading": "11. Students and minors",
    "body": [
      "FindEZ accounts are for people aged 13 or older, subject to any higher minimum that applies where they live. A person below the age of legal majority needs a parent or legal guardian's permission where required. School or team use does not automatically replace that requirement.",
      "FindEZ is not directed to children under 13, and they may not create accounts. Contact us if you believe an under-13 child has provided personal information so we can restrict use and address deletion or other legally required steps.",
      "Schools should obtain the approvals required for their use and contact us before submitting regulated student education records or requiring school-specific processing terms. FindEZ remains responsible for obligations that apply to it; this notice does not certify COPPA, FERPA, or worldwide student-privacy compliance."
    ]
  },
  {
    "id": "changes",
    "heading": "12. Updates and contact",
    "body": [
      "We will update the effective date when this notice changes and provide further notice or choices when required. Material changes to data use apply prospectively unless otherwise permitted by law.",
      "Privacy and legal contact: AI Robots Inc, 887 Poppy Ct, Sunnyvale, CA 94086, United States. Email: info@findez.ai."
    ]
  }
];

export const termsSections: LegalSection[] = [
  {
    "heading": "1. Your account and eligibility",
    "body": [
      "You must be at least 13 and meet any higher applicable minimum age to use FindEZ. If you are below the age of legal majority, a parent or legal guardian must authorize your use where required. A teacher or team lead cannot waive a legal requirement for parental permission.",
      "Use accurate account information, protect your credentials, and notify us of unauthorized use. If you act for an organization, you must have authority to agree for it. Separate written organization agreements take precedence where they apply."
    ]
  },
  {
    "heading": "2. What FindEZ provides",
    "body": [
      "FindEZ helps record, identify, find, organize, and share inventory. It also provides organization and workspace collaboration, documents, project and reminder tools, optional account memory, and scoped API integrations. Features can change or be experimental. The service is an aid to record keeping and human decisions; it does not guarantee that an item is present, available, compatible, or safe."
    ]
  },
  {
    "heading": "3. AI and equipment safety",
    "body": [
      "AI, OCR, barcode, quantity, measurement, and compatibility results can be incomplete or incorrect. Review results and source records before saving, purchasing, assembling, or handling equipment. Follow manufacturer instructions and applicable safety procedures. Do not rely on FindEZ alone for medical, legal, financial, accounting, or safety-critical decisions."
    ]
  },
  {
    "heading": "4. Your content and sharing",
    "body": [
      "You retain ownership of your content. You grant AI Robots Inc a non-exclusive, worldwide, royalty-free permission to host, copy, process, transmit, and display it as needed to provide, secure, and support the service you request. This permission ends when content is deleted, subject to lawful retention, backups, and content owned by others.",
      "You must have the right to upload and share content. Do not upload confidential, regulated, export-controlled, infringing, or sensitive personal information unless you have authorization and the service is suitable. Inventory photo links and photo-processing limitations are explained in the Privacy Policy.",
      "Organization, workspace, inventory, and shared-Space permissions determine collaborator access. Administrative control does not automatically grant access to restricted inventory contents. Review roles, accept invitations only for access you want, and keep invite codes confidential. Linking a Space does not transfer its ownership. Revoking access does not retrieve copies already made. Confirmed non-personal manufacturer facts may improve the shared parts catalog; private inventory details are not published as catalog entries."
    ]
  },
  {
    "heading": "5. Acceptable use and reporting",
    "body": [
      "Do not violate rights or laws; harass, impersonate, or exploit others; upload malware or unlawful content; bypass access controls; misuse credentials or invitations; disrupt the service; send spam; or extract data you are not authorized to access. Restrictions on reverse engineering apply only to the extent allowed by law.",
      "Report abuse, infringement, security concerns, or unauthorized disclosure to info@findez.ai with the relevant information. We may restrict access or remove content to protect users, comply with law, or address a material violation. We will provide notice and a way to raise a concern where reasonably possible."
    ]
  },
  {
    "heading": "6. Privacy and connected services",
    "body": [
      "The Privacy Policy explains data handling, storage, permission choices, and privacy requests. It is a notice, not consent to unrelated processing.",
      "Sign-in, payments, notifications, and assistants you connect can be subject to separate provider terms. You are responsible for choosing permissions for external assistants and keeping API keys secure. An integration key can allow software to read or modify the inventory within its current scope. Use the minimum required permissions, review automated changes, and revoke unused or compromised keys in Settings. Expiry, revocation, ownership changes, and inventory restrictions can stop an integration. API access does not include every feature of the FindEZ apps; the API documentation describes supported operations and limits. This does not remove obligations that the law places on FindEZ."
    ]
  },
  {
    "heading": "7. Plans and payments",
    "body": [
      "Prices, renewal periods, trial conditions, and cancellation information will be shown before a purchase. A free pilot ending does not authorize a charge. You must affirmatively authorize a purchase.",
      "Apple manages App Store purchases and its cancellation and refund processes. Other purchases follow the terms shown at checkout. Mandatory cancellation, refund, and consumer rights still apply. Disabling an app or deleting an account does not necessarily cancel a store subscription; manage it with the purchase provider."
    ]
  },
  {
    "heading": "8. Service changes and account closure",
    "body": [
      "We may maintain, update, or discontinue features. We do not promise uninterrupted operation or permanent storage. Keep appropriate copies of important records.",
      "You can request permanent account deletion in Settings. Transfer or remove resources you own when the app requires this before deletion so other members are not left without an owner. We may suspend or end access for serious or repeated violations, security risks, legal requirements, or service discontinuation, with notice where practical. Content deletion and retention limits are described in the Privacy Policy."
    ]
  },
  {
    "heading": "9. Intellectual property and feedback",
    "body": [
      "AI Robots Inc and its licensors own the service software and branding, apart from your content. You may use the service as intended and as allowed by your plan. You may provide feedback voluntarily; we may use it to improve the service without paying compensation."
    ]
  },
  {
    "heading": "10. Warranties and liability",
    "body": [
      "To the extent permitted by law, the service is provided as is and as available. We do not guarantee accuracy, uninterrupted availability, or fitness for a particular use. Statutory warranties and protections that cannot be excluded remain in place.",
      "To the extent permitted by law, AI Robots Inc is not liable for indirect or consequential losses, lost profits, or losses caused by relying on unverified AI output. Our aggregate liability for service-related claims is limited to the greater of US $100 or the amount you paid us for the service in the 12 months before the event giving rise to the claim.",
      "These exclusions and limits do not apply to fraud, intentional misconduct, death or personal injury caused by negligence where liability cannot be excluded, or any other liability that applicable law does not permit us to limit. Mandatory consumer remedies remain available."
    ]
  },
  {
    "heading": "11. Organization claims",
    "body": [
      "To the extent permitted by law, an organization is responsible for third-party claims arising from its unlawful content, unauthorized use, or material breach, including reasonable defense costs. This does not apply to individual consumers where prohibited or to claims caused by our own unlawful conduct."
    ]
  },
  {
    "heading": "12. Law and disputes",
    "body": [
      "California law governs these Terms, except that mandatory protections and court rights in your home jurisdiction remain applicable. Contact us to try to resolve a concern before bringing a claim. Nothing here prevents urgent relief, an eligible small-claims case, or a claim within a statutory deadline. These Terms do not require private arbitration or waive class-action rights."
    ]
  },
  {
    "heading": "13. Changes and general terms",
    "body": [
      "We will post an updated effective date and give required notice of material changes. Changes apply prospectively unless the law permits otherwise. If you do not agree, stop using the service and contact us about account closure.",
      "An unenforceable provision is limited as necessary without removing the rest of the Terms. Failure to enforce a provision is not a waiver. An assignment or business transfer does not remove mandatory user rights. Ownership, lawful retention, and provisions intended to survive closure continue as applicable."
    ]
  },
  {
    "heading": "14. Contact",
    "body": [
      "AI Robots Inc, 887 Poppy Ct, Sunnyvale, CA 94086, United States. Questions, concerns, and legal notices: info@findez.ai."
    ]
  }
];
