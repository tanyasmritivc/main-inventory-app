import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/profile_store.dart';
import '../../core/ui/app_text.dart';
import '../checkout/checkout_page.dart';
import '../documents/documents_page.dart';
import '../notifications/notification_bell.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/setup_questions_page.dart';
import 'profile_hub_page.dart';
import 'profile_page.dart';

/// Standalone account destination. The legacy profile/settings body is embedded
/// only inside its own opaque page, never directly over the caller's route.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, this.store});
  final ApiClient api;
  final ProfileStore? store;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final ApiClient _api;
  late final ProfileStore _store;
  @override
  void initState() {
    super.initState();
    _api = ApiClient.forAccount(widget.api, widget.api.accountId ?? '');
    _store = widget.store ?? ProfileStore(api: _api);
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const AppText('Account'),
      actions: [NotificationBell(api: _api)],
    ),
    body: SafeArea(
      top: false,
      child: ProfileHubPage(
        api: _api,
        store: _store,
        showHeading: false,
        onOpenProfile: () =>
            _open(ProfilePage(api: _api, accountOnly: true, store: _store)),
        onOpenSettings: () => _open(
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(title: const AppText('Settings')),
            body: SafeArea(
              top: false,
              child: ProfilePage(api: _api, settingsOnly: true, store: _store),
            ),
          ),
        ),
        onOpenDocuments: () => _open(DocumentsPage(api: _api)),
        onOpenNotifications: () => _open(NotificationsPage(api: _api)),
        onOpenCheckouts: () => _open(CheckoutPage(api: _api)),
        onOpenTour: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (tourContext) => SetupQuestionsPage(
                api: _api,
                isReplay: true,
                onFinished: () => Navigator.of(tourContext).pop(),
              ),
            ),
          );
        },
      ),
    ),
  );
}
