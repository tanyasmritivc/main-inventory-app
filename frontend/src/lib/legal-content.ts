/**
 * Review drafts, not a compliance certification. Do not deploy these revisions
 * until docs/legal-publication.md is resolved. Current published policies remain
 * in force. In particular, do not invent consent or processor retention promises.
 */
export const legalPublication = {
  status: "draft",
  revised: "October 4, 2026",
  revisedISO: "2026-10-04",
  operator: "AI Robots Inc",
  contact: "info@findez.ai",
} as const;

export type LegalSection = {
  id: string;
  heading: string;
  body: string[];
  bullets?: string[];
  links?: { label: string; href: string }[];
  emphasized?: boolean;
};

export const privacyIntro = "AI Robots Inc, a California corporation (\"FindEZ,\" \"we,\" \"us\" or \"our\"), operates FindEZ AI. This notice explains the information used by our mobile app, website, APIs and related services, its uses and disclosures, and your choices. Independently operated services have their own privacy notices.";

export const privacySections: LegalSection[] = [
  {
    id: "information",
    heading: "1. Information we collect",
    body: ["We receive information you provide, information created through use of FindEZ, information collaborators add to shared work and information from services you connect. Do not upload someone else's information without the necessary authority."],
    bullets: [
      "Account and profile: email, account ID, authentication information, display name, optional profile photo/color, organization, role and contact email. Apple or Google sign-in supplies information according to your choices and provider settings.",
      "Physical-world records: Spaces, items, quantities, locations you enter, bins, labels, barcodes, manufacturer/part identifiers, notes, tags, photos, purchase-source information, project requirements and checkouts. A location such as 'Garage / Shelf B' is content you supply, not necessarily your phone's geographic location.",
      "Uploads and AI interactions: selected photos and camera captures, spreadsheets, documents and extracted text, questions, conversation history, answers, source snapshots, corrections and unresolved capture reviews. Photos and files may contain people, addresses or other personal information beyond the object you intend to capture.",
      "Collaboration: Team and shared-Space membership, permissions, invitation codes, assignments, member activity, documents, notifications and lending records. An optional download handoff saves an invitation pointer in account metadata; it does not grant membership.",
      "Service operation: IP addresses and request times in server logs, app/device information needed for operation and support, error/security records, usage counters and push-notification tokens. Payment providers handle payment details and we receive transaction, plan and entitlement information.",
      "Support and feedback: correspondence and information needed to investigate a problem or respond to a privacy request.",
    ],
  },
  {
    id: "permissions",
    heading: "2. Permissions and local preferences",
    body: [
      "Camera and photo access let you capture or select an image. Microphone and speech-recognition access support voice input; the platform speech service may process audio under its own terms. Resulting text can be sent to FindEZ when you submit it. Notification permission enables device alerts. These permissions do not authorize unrelated uses.",
      "Deny or revoke permissions in device settings; the corresponding feature may be unavailable. Theme, text-size and personal Space-icon choices are device-local preferences in the current mobile app. Clearing local preferences does not delete server-side inventory or account data.",
    ],
  },
  {
    id: "purposes",
    heading: "3. Why we use information",
    body: [
      "We use information to authenticate accounts; record, search and organize physical items; process requested scans and AI questions; save documents and conversations; coordinate Teams, sharing, projects and checkouts; deliver requested notifications; administer plans; answer support requests; detect abuse; troubleshoot failures; and meet legal obligations.",
      "An AI answer can use relevant records you are authorized to access, including shared inventory. An answer is not proof that a physical item is present, compatible or safe. Confirmed non-personal product facts, such as a barcode, manufacturer or part number, may contribute to the shared catalog. Private quantities, locations, notes, account identifiers, photographs and documents are not intended to become public catalog entries.",
      "Where a legal basis is required, processing may be necessary to provide the service you request or fulfill a contract, meet a legal obligation, pursue legitimate interests such as security and reliability, or rely on consent where required. Contact us about the basis for a specific use or exercise applicable rights below.",
    ],
  },
  {
    id: "ai",
    heading: "4. AI processing, operators and training",
    body: [
      "Photo analysis sends your submitted image to the FIND vision pipeline for object identification and visible text/barcode reading. Source images and available crops may be saved with items or capture reviews. FindEZ requests cleanup of temporary FIND jobs after processing, including on failure. A cleanup request is not a guarantee that every processor log or backup is immediately erased.",
      "Language features send questions, relevant conversation context, accessible inventory details and, for document analysis, extracted text to the dedicated FTCTools language gateway and its model infrastructure. Images are not sent through the application's text-only language path. The application does not use an OpenAI runtime client or fallback; this does not certify the gateway's downstream arrangements.",
      "FindEZ does not currently use customer photos, chats or documents to train or fine-tune AI models. Processing content to provide requested features, including photo identification, AI answers and document analysis, is different from model training.",
      "Model training is a future possibility, not a current feature or permission granted by this notice. Before any future training use, we will explain the data involved, who will train the models, retention and withdrawal options, and ask for separate, explicit opt-in consent. Declining that optional use will not prevent ordinary use of FindEZ.",
      "REVIEW REQUIRED BEFORE PUBLICATION: The operator clarified that FindEZ does not currently train on customer content. Independently verify FIND and language-model operators' permitted uses and downstream training practices, identities, processing countries, retention periods and deletion arrangements. Do not extend FindEZ's statement into an unsupported provider-wide guarantee or silently authorize a future use of previously collected content.",
      "Do not submit confidential, regulated or highly sensitive material for AI processing. You can avoid a feature by not using it; a privacy notice alone is not a substitute for explicit permission or another legal authorization when required.",
    ],
  },
  {
    id: "disclosures",
    heading: "5. Who receives information",
    body: ["Information can be disclosed as follows. Using a service provider does not waive your rights or remove our own obligations."],
    bullets: [
      "Collaborators: accessible records, member identity and activity are available according to Team or Space permissions. Owners and authorized managers manage membership. Invitation links can be forwarded; treat codes and links as confidential.",
      "Service operations: hosting/network infrastructure, authentication/database/storage services, FIND and language-model operators, sign-in, email, push-notification, payment, support and security services can receive data needed for their roles. Protection and permitted-use arrangements must be verified before this revision is published.",
      "Authorized integrations: an external assistant or automation using your API key can access or change records within the key's scope. Revocation stops future authorized API use, not copies already received. The external service's privacy terms also apply.",
      "Law and safety: disclosures may meet a binding legal requirement or be reasonably necessary to protect rights, investigate abuse, respond to an incident or protect people, subject to applicable law.",
      "Business changes: information may transfer in a merger, acquisition, reorganization or sale of the service, subject to legally required protections and notice of materially different practices.",
    ],
  },
  {
    id: "file-links",
    heading: "6. File URLs and sharing limitations",
    emphasized: true,
    body: [
      "Current limitation: the item-photo and document storage buckets are configured for public file delivery. Someone who knows a direct file URL may be able to retrieve the file without signing in, even when an app screen or API route requires authentication. Do not upload sensitive files assuming that every file URL is access-controlled.",
      "A short-lived link or revoked membership does not necessarily invalidate another direct file URL, screenshot, download or export. Profile photos use a separate private bucket with signed URLs. Contact us to report an unintended disclosure or request removal; we cannot recall independent copies held by other people.",
    ],
  },
  {
    id: "storage-tracking",
    heading: "7. Cookies, device storage and tracking",
    body: [
      "The website uses authentication cookies and browser storage for sessions and functional preferences. Blocking or clearing them can sign you out or reset preferences. Mobile authentication and preferences also use device storage.",
      "The current application source does not integrate an advertising-tracker SDK. REVIEW REQUIRED BEFORE PUBLICATION: Confirm the business's no-sale/no-cross-context-advertising practices and all deployed analytics or third-party tags. Business practices cannot be certified solely by reading application source.",
      "The current application does not implement a special response to the legacy Do Not Track header. Any legally required opt-out preference signal must still be honored where applicable. Independently operated sign-in, payment or linked websites may collect information under their own notices when you use them.",
    ],
  },
  {
    id: "retention",
    heading: "8. Retention and deletion",
    body: [
      "Saved account content is retained to provide the account and requested features until you delete it or close your account, subject to applicable retention obligations and the limits below. Notification history is ordinarily available in the app for 14 days; this is not a promise that all underlying activity is erased after 14 days. The optional invitation-download pointer expires after 30 days.",
      "In-app account deletion requests removal of your account and associated application data/files. Uninstalling or signing out does not delete server data. If deletion fails, retry or contact info@findez.ai. Content owned by another person or organization and copies held by collaborators may remain with their owner.",
      "Backups, processor records, security logs, payment/dispute records and information subject to a legal hold may persist where necessary and lawful. Local preferences and cached files may remain on devices. REVIEW REQUIRED BEFORE PUBLICATION: Confirm backup/log/provider schedules, full deletion coverage (including profile photos, Team files and processor data), and reapplication of deletion after a backup restore. No immediate or universal erasure guarantee is made here.",
    ],
  },
  {
    id: "choices",
    heading: "9. Your choices and privacy requests",
    body: [
      "Available controls let you edit your profile, delete records, manage sharing, leave joined Spaces or Teams, revoke API keys, change device permissions and request account deletion in settings. Permission changes affect future access, not every previously distributed copy. Contact us if a control is unavailable or you need help.",
      "Depending on applicable law, you may have rights to access or know your information, correct or delete it, receive a portable copy, object to or restrict processing, withdraw consent, or appeal a denied request. Email info@findez.ai with the account email and requested action. Do not send passwords or sensitive identity documents unless we arrange a secure verification method.",
      "We may reasonably verify identity and an agent's authority. We will respond within applicable legal deadlines, explain denials and provide any required appeal route. Send an appeal to the same address with 'Privacy appeal' in the subject. You may complain to the competent regulator. We will not unlawfully discriminate against you for exercising rights. Withdrawal does not make earlier lawful processing unlawful.",
    ],
    links: [{ label: "Email a privacy request", href: "mailto:info@findez.ai?subject=FindEZ%20privacy%20request" }],
  },
  {
    id: "security-transfers",
    heading: "10. Security and international processing",
    body: [
      "FindEZ uses account authentication, access checks and HTTPS for public app/API endpoints. This does not mean every processing hop or file is private. The current server-to-FIND photo-processing hop uses HTTP, not an encrypted transport. The public-file limitations above also apply. Do not assume end-to-end encryption or absolute confidentiality.",
      "No service can guarantee perfect security. Report suspected unauthorized access to info@findez.ai. Disclosure of a limitation does not remove legally required safeguards or incident-notification obligations.",
      "Information may be processed where FindEZ, hosting infrastructure and service operators are located, including outside your state or country. REVIEW REQUIRED BEFORE PUBLICATION: Confirm processing countries and any required transfer safeguards or representative contacts. You may request information about applicable safeguards from us.",
    ],
  },
  {
    id: "children",
    heading: "11. Children, students and organizations",
    body: [
      "Account holders must be at least 13. Minors must have permission and supervision from a parent or legal guardian. The current service does not implement a verified parental-consent workflow for children under 13. Do not create an under-13 account or submit an under-13 child's personal information without an approved lawful arrangement.",
      "A school or Team invitation is not verified parental consent or proof that FindEZ satisfies student-privacy laws. Organizations need authority to submit information; this does not transfer our legal obligations to them. Contact info@findez.ai if a child's information was collected improperly so we can investigate and take appropriate action.",
    ],
  },
  {
    id: "changes-contact",
    heading: "12. Changes and contact",
    body: [
      "A published revision will show its effective date. We will provide notice of material changes and obtain additional permission when legally required before an incompatible new use of existing information. Changing this notice is not retroactive authorization for an undisclosed use.",
      "Contact AI Robots Inc at info@findez.ai for privacy questions, removal requests or security concerns. REVIEW REQUIRED BEFORE PUBLICATION: Confirm whether the intended markets require additional business/legal-notice or representative contact details. No postal address has been supplied.",
    ],
    links: [{ label: "Contact FindEZ", href: "mailto:info@findez.ai" }],
  },
];

export const termsIntro = "These Terms of Service are between you and AI Robots Inc, a California corporation (\"FindEZ,\" \"we,\" \"us\" or \"our\"), for the FindEZ mobile app, website, APIs and related services (the \"Service\"). Review these Terms before creating an account or using the Service. The Privacy Policy separately explains information practices; it is not blanket consent to every form of processing.";

export const termsSections: LegalSection[] = [
  {
    id: "eligibility",
    heading: "1. Eligibility and accounts",
    body: [
      "Account holders must be at least 13. Minors need a parent or legal guardian's permission and supervision. You must be able to enter a binding agreement or have a lawful arrangement through an authorized adult. We do not currently offer a verified parental-consent workflow for children under 13.",
      "Provide accurate information, protect credentials and notify us of suspected unauthorized access. Do not share passwords or impersonate others. Your responsibility does not remove our responsibility for our own security failures or override consumer rights.",
      "If accepting for an organization, you must have authority to bind it. Administrators must manage members and have authority to provide student, employee or other personal information. Organizational acceptance does not replace parental consent or another authorization required by law.",
    ],
  },
  {
    id: "service",
    heading: "2. What FindEZ does",
    body: [
      "FindEZ helps record and retrieve information about physical items through photos, scanning, search, AI assistance, documents, Spaces, Teams, projects and checkouts. Features can be experimental, limited or platform-dependent. Future concepts in plans are not included features unless made available.",
      "FindEZ is a record-keeping aid, not a guarantee that an item exists, is in the recorded place, belongs to you, is available, compatible or safe. It is not an emergency, safety, accounting or purchasing-authority system. Verify important records and keep independent copies where needed.",
    ],
  },
  {
    id: "sharing",
    heading: "3. Spaces, Teams and integrations",
    body: [
      "Review permissions you grant. Authorized owners/managers manage members, roles, invitations and linked Spaces. Linking a Space does not itself transfer ownership. Recipients must accept invitations before membership is granted; a download/account handoff is not membership consent.",
      "Treat links, codes and API keys as confidential. Links can be forwarded. Authorized people may download content or change records within their permissions. Revocation does not recall copies or necessarily invalidate public file URLs. The Privacy Policy explains current file-delivery limitations.",
      "Choose appropriate API-key scopes and review an external assistant's or automation service's terms. Disconnecting does not necessarily delete its copies or undo its actions. Nothing here excuses our own breach of duty.",
    ],
    links: [{ label: "File-sharing limitations", href: "/privacy#file-links" }],
  },
  {
    id: "content",
    heading: "4. Your content and limited processing permission",
    body: [
      "You retain your rights in submitted records, photos, files, notes and messages. You grant us a non-exclusive, worldwide, royalty-free license to host, copy, process, transmit and display content and create necessary technical transformations such as image crops, only to provide, maintain, secure and support the Service you request, comply with law and enforce these Terms. Service operators may perform those tasks under appropriate arrangements.",
      "This is not ownership transfer, permission to sell private content or authorization to train or fine-tune AI models. FindEZ does not currently use customer photos, chats or documents for model training. Any future training program will require separate, explicit opt-in consent after explaining its scope, operators, retention and withdrawal options; accepting these Terms does not provide that consent. Declining optional training will not prevent ordinary use of FindEZ.",
      "Have the rights and permissions needed to submit and share content. Avoid confidential, export-controlled or regulated data, passwords, payment-card details, health records, government identifiers or sensitive student information when the Service is not suitable or authorized. Do not infringe another person's rights.",
      "Confirmed non-personal product facts may contribute to the catalog as described in the Privacy Policy. Deletion ends the processing license except for copies lawfully remaining in backups, legal records or content controlled by another owner; it cannot erase every independent copy.",
    ],
  },
  {
    id: "ai",
    heading: "5. AI, scanning and human review",
    body: [
      "AI, OCR, barcode interpretation, summaries, measurements, compatibility, stock and location answers may be incomplete, outdated or wrong. Confidence scores and plausible matches do not prove identity, ownership or suitability. Review outputs before saving, purchasing, building or handling equipment.",
      "Do not rely on FindEZ alone for engineering, electrical, medical, legal, financial, emergency or other professional advice, or decisions materially affecting a person. Follow manufacturer instructions and applicable safety, competition and workplace rules. Disclaimers do not waive duties or liability that cannot legally be excluded.",
    ],
  },
  {
    id: "acceptable-use",
    heading: "6. Acceptable use",
    body: ["Do not use the Service to:"],
    bullets: [
      "Violate law, infringe rights, harass, impersonate, exploit children or distribute unlawful content, malware or spam.",
      "Access records without authorization, misuse invitations/credentials, evade security or limits, or disrupt the Service.",
      "Impose unreasonable automated load or scrape private records. Use the documented API within its permissions and limits.",
      "Reverse engineer or bypass technical restrictions except where law or an applicable open-source license permits it.",
      "Present an AI answer as an independently verified fact or use the Service for prohibited high-impact or safety-critical automation.",
    ],
  },
  {
    id: "plans",
    heading: "7. Plans and payments",
    body: [
      "Features, quotas, price, billing period, any automatic renewal/trial conversion and cancellation method must be disclosed before purchase. A free account or pilot does not authorize a charge. Additional purchase terms apply when presented and accepted; these Terms do not invent a subscription or payment method.",
      "Use Apple's billing/subscription/refund controls for Apple purchases. For direct billing, follow the controls and purchase terms at checkout or contact support. Mandatory refund and cancellation rights remain available. Deleting an app or account does not necessarily cancel a separately managed subscription.",
    ],
  },
  {
    id: "third-parties",
    heading: "8. Third parties and Apple distribution",
    body: [
      "Independent sign-in/payment services, external integrations and linked websites have their own terms. Their availability and content are outside our direct control, without relieving us of obligations for providers engaged to process information or perform our contract.",
      "The App Store license is governed by the EULA identified for FindEZ there, including Apple's Standard EULA when no custom EULA is provided, and applicable usage rules. These service terms do not declare a custom EULA filed with Apple. FindEZ, not Apple, provides and supports the Service. Mandatory platform and consumer protections prevail over conflicting restrictions here.",
    ],
    links: [{ label: "Apple Standard EULA", href: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" }],
  },
  {
    id: "intellectual-property",
    heading: "9. Intellectual property and feedback",
    body: [
      "Except for your content and third-party rights, the Service, software, branding and design belong to AI Robots Inc or its licensors. Subject to these Terms and applicable platform/open-source licenses, you may use the Service as intended. No other rights are granted by implication.",
      "We may use voluntary suggestions to improve the Service without payment or an obligation to implement them; this does not grant ownership of private inventory or permission to publish identity/confidential content without authority. Report infringement to info@findez.ai with details identifying the content and your rights. Do not send knowingly false reports.",
    ],
  },
  {
    id: "availability",
    heading: "10. Availability, changes and termination",
    body: [
      "Maintenance, outages and product changes can affect availability. We do not promise continuous service or permanent storage. Feature changes/discontinuation remain subject to applicable notice, refund and other obligations. Keep independent records of important information.",
      "You may stop using FindEZ and request account deletion through available controls or support. We may restrict/suspend access when reasonably necessary for a material breach, security risk, unlawful use, nonpayment or legal requirement. Where lawful and practical, we will explain the reason and provide a route to resolve or appeal it; urgent protective action may precede notice.",
      "On termination access ends. Provisions that reasonably survive (ownership, lawful retention, unpaid amounts, disclaimers, liability and dispute rights) continue only to the extent valid under law. See the Privacy Policy for deletion limits.",
    ],
  },
  {
    id: "warranties",
    heading: "11. Disclaimers",
    emphasized: true,
    body: [
      "TO THE EXTENT PERMITTED BY LAW, THE SERVICE IS PROVIDED 'AS IS' AND 'AS AVAILABLE.' WE DISCLAIM IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT, AND DO NOT WARRANT UNINTERRUPTED OPERATION OR ACCURATE, COMPLETE OR ERROR-FREE AI OUTPUT.",
      "This does not exclude a warranty, duty of care, reasonable security obligation or consumer remedy that cannot legally be excluded. No policy or disclaimer guarantees that an incident or legal claim cannot occur.",
    ],
  },
  {
    id: "liability",
    heading: "12. Liability limits and rights that remain",
    emphasized: true,
    body: [
      "TO THE EXTENT PERMITTED BY LAW, AI ROBOTS INC WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY OR PUNITIVE DAMAGES, INCLUDING LOST PROFITS, BUSINESS INTERRUPTION OR LOST DATA ARISING FROM THE SERVICE. SUBJECT TO THE EXCEPTIONS BELOW, OUR AGGREGATE LIABILITY FOR SERVICE-RELATED CLAIMS WILL NOT EXCEED THE GREATER OF US $100 OR THE AMOUNT YOU PAID US FOR THE SERVICE IN THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM.",
      "These limits do not apply to fraud, intentional misconduct, gross negligence, death/personal injury where liability cannot lawfully be limited, or other liability or statutory rights that cannot be excluded. They do not prevent privacy complaints, regulatory reports or consumer remedies. Where a jurisdiction prohibits a limitation, only the lawful limitation, if any, applies. Counsel must review enforceability for actual users and markets before publication.",
    ],
  },
  {
    id: "business-claims",
    heading: "13. Organization responsibility for third-party claims",
    body: [
      "To the extent permitted by law, an organization accepting these Terms agrees to indemnify AI Robots Inc for third-party claims and reasonable costs to the extent caused by its unlawful content, infringement or material breach. This does not cover our own fault, breach of duty or unlawful acts, and is not imposed on individual consumers by this section.",
      "We must promptly notify the organization (unless delay causes no material prejudice), reasonably cooperate and not settle with an admission/non-monetary obligation for it without consent. It may control the defense with competent counsel, subject to conflicts and our participation at our own expense. This provision requires legal review before publication.",
    ],
  },
  {
    id: "law-disputes",
    heading: "14. California law and disputes",
    body: [
      "Subject to mandatory law, California law governs these Terms without its conflict-of-law rules. Mandatory consumer protections and any right to use the law/courts of your home jurisdiction remain intact. No exclusive court is selected contrary to those rights.",
      "Contact info@findez.ai to try to resolve concerns informally. Discussion is voluntary and does not postpone filing deadlines or prevent urgent relief, eligible small-claims proceedings, regulatory complaints or other remedies. These Terms impose no mandatory arbitration or class-action waiver. No provision can prevent someone from bringing a claim.",
    ],
  },
  {
    id: "changes",
    heading: "15. Changes to these Terms",
    body: ["A published revision will identify its effective date. We will provide legally required notice of material changes and seek fresh acceptance when required. Changes apply prospectively, not to remove rights arising earlier. You may stop using the Service if you do not accept a valid change, without losing a mandatory remedy or refund."],
  },
  {
    id: "general",
    heading: "16. General and contact",
    body: [
      "An unenforceable provision is limited only as law permits; the remainder continues where valid. Non-enforcement once is not a waiver. Assignment must not reduce mandatory rights; a business transfer remains subject to privacy and contractual obligations. A separate signed agreement governs where it expressly supersedes these Terms.",
      "Contact AI Robots Inc at info@findez.ai for service complaints, questions or legal notices. REVIEW REQUIRED BEFORE PUBLICATION: Confirm any additional contact details required for the intended markets. Email is a contact method, not a declaration that every formal notice may legally be served by email.",
    ],
    links: [{ label: "Contact FindEZ", href: "mailto:info@findez.ai" }, { label: "Privacy Policy", href: "/privacy" }],
  },
];
