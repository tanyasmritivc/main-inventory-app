import 'package:supabase_flutter/supabase_flutter.dart';
import 'last_place.dart';

/// Sign-out and cache clearing must only follow a confirmed server deletion.
Future<void>? _pending;
String? _pendingActor;
Future<void> requestAccountDeletion() {
  final actor = Supabase.instance.client.auth.currentUser?.id;
  if (_pending != null && _pendingActor == actor) return _pending!;
  _pendingActor = actor;
  return _pending = _performDeletion().whenComplete(() {
    if (_pendingActor == actor) {
      _pending = null;
      _pendingActor = null;
    }
  });
}

Future<void> _performDeletion() async {
  final client = Supabase.instance.client;
  final actor = client.auth.currentUser?.id;
  const fallback =
      'Account deletion did not finish. Some data may already have been removed. Try again or contact info@findez.ai.';
  if (actor == null) {
    throw const FormatException('Please sign in before deleting your account.');
  }
  try {
    final response = await client.functions.invoke('delete-user');
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['success'] != true) {
      throw const FormatException(fallback);
    }
    if (client.auth.currentUser?.id != actor) {
      throw const FormatException(
        'The signed-in account changed. Your current account was not signed out.',
      );
    }
    await LastPlaceStore(actor).clear();
  } on FunctionException catch (error) {
    final data = error.details;
    if (data is Map && data['code'] == 'OWNERSHIP_REQUIRED') {
      throw FormatException(
        data['error'] as String? ??
            'Delete or transfer the organizations and workspaces you own before deleting your account.',
      );
    }
    if (data is Map && data['code'] == 'SHARED_RECORDS') {
      throw const FormatException(
        'Some Spaces you created belong to another account. Ask its owner to transfer those records before deleting your account.',
      );
    }
    throw const FormatException(fallback);
  }
}
