import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    Map<String, dynamic>? body;
    if (client.auth.currentUser?.identities?.any(
          (identity) => identity.provider == 'apple',
        ) ??
        false) {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );
      if (client.auth.currentUser?.id != actor) {
        throw const FormatException(
          'The signed-in account changed. No deletion was requested.',
        );
      }
      body = {
        'apple_authorization_code': credential.authorizationCode,
        'apple_client_id': 'com.findez.app',
      };
    }
    final response = await client.functions.invoke('delete-user', body: body);
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
  } on SignInWithAppleAuthorizationException catch (error) {
    throw FormatException(
      error.code == AuthorizationErrorCode.canceled
          ? 'Account deletion cancelled. Your account was not deleted.'
          : 'Apple authorization could not be confirmed. Your account was not deleted. Try again.',
    );
  } on FunctionException catch (error) {
    final data = error.details;
    if (data is Map &&
        const [
          'APPLE_REAUTH_REQUIRED',
          'APPLE_REVOCATION_UNAVAILABLE',
          'APPLE_IDENTITY_MISMATCH',
        ].contains(data['code'])) {
      throw FormatException(
        data['error'] as String? ??
            'Confirm Sign in with Apple again before deleting your account.',
      );
    }
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
