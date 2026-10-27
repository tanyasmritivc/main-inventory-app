import 'package:url_launcher/url_launcher.dart';

/// A supported URL can still fail to open (for example, no mail account).
Future<bool> tryOpenExternalUrl(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
