import '../../core/ui/findez_wordmark.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/legal_links.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/terms_of_service_page.dart';
import '../onboarding/onboarding_prefs.dart';
import 'package:mobile/core/ui/app_text.dart';

/// Optional presentation adapter. Authentication and email validation stay here.
class AuthPresentation {
  const AuthPresentation({
    required this.apple,
    required this.google,
    required this.email,
    required this.closeEmail,
    required this.emailForm,
    required this.showEmail,
    required this.busy,
    this.method,
    this.error,
  });
  final VoidCallback apple, google, email, closeEmail;
  final Widget emailForm;
  final bool showEmail, busy;
  final String? method, error;
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.onAuthChanged,
    this.fromOnboarding = false,
    this.onBackToSetup,
    this.initialMethod,
    this.trialItemCount,
    this.sampleTrial = false,
    this.presentationBuilder,
    this.beforeAuth,
    this.onSignupUser,
  });

  final VoidCallback? onAuthChanged;
  final bool fromOnboarding;
  final VoidCallback? onBackToSetup;
  final String? initialMethod;
  final int? trialItemCount;
  final bool sampleTrial;
  final Widget Function(BuildContext, AuthPresentation)? presentationBuilder;
  final Future<void> Function(String method, bool signup)? beforeAuth;
  final Future<void> Function(User user)? onSignupUser;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _profileRole;
  late final TextEditingController _organization;
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _isLogin = true;
  bool _showEmail = false, _moreOptions = false;
  bool _edge = false;
  double _edgeDistance = 0;
  bool _legalAccepted = false;
  Map<String, dynamic> get _legalAcceptance => {
    'terms_version': legalTermsVersion,
    'terms_url': legalDocumentUrl(LegalDocumentKind.terms).toString(),
    'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
    'eligibility_attested': true,
  };
  bool _loading = false;
  bool _resending = false;
  String? _error;

  bool _needsEmailVerification = false;
  String? _verificationEmail;

  static const _oauthRedirectTo = 'io.supabase.flutter://login-callback';

  OAuthProvider? _oauthProviderLoading;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    if (widget.initialMethod == 'email') _showEmail = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialMethod == 'apple') unawaited(_signInWithApple());
      if (widget.initialMethod == 'google') unawaited(_signInWithGoogle());
    });
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _profileRole = TextEditingController();
    _organization = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    assert(() {
      final keepAlive = <Object?>[_oauthSignIn];
      return keepAlive.isNotEmpty;
    }());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool _validateSignupIdentity() {
    if (_isLogin) return true;
    if (!_legalAccepted) {
      setState(
        () => _error =
            'Confirm your eligibility and accept the Terms of Service to create an account.',
      );
      return false;
    }
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final displayName = [firstName, lastName].join(' ').trim();
    String? validationError;
    if (firstName.isEmpty || lastName.isEmpty) {
      validationError = 'Enter your first and last name.';
    } else if (displayName.length > 100) {
      validationError = 'Name must be under 100 characters.';
    } else if (_profileRole.text.trim().length > 120 ||
        _organization.text.trim().length > 120) {
      validationError =
          'Role and organization must each be under 120 characters.';
    }
    if (validationError == null) return true;
    setState(() => _error = validationError);
    return false;
  }

  Future<void> _oauthSignIn(OAuthProvider provider) async {
    if (_loading) return;
    if (!mounted) return;
    if (!_validateSignupIdentity()) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = provider;
      _error = null;
      _needsEmailVerification = false;
      _verificationEmail = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.signInWithOAuth(provider, redirectTo: _oauthRedirectTo);
    } on AuthException catch (e) {
      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e).$1);
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _oauthProviderLoading = null;
        });
      }
    }
  }

  bool _isDuplicateEmailMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('already exists') ||
        lower.contains('duplicate');
  }

  String _friendlyAuthError(String message) {
    final m = message.trim();
    final lower = m.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('invalid email') ||
        (lower.contains('email') && lower.contains('invalid'))) {
      return 'Enter a valid email address.';
    }
    if (lower.contains('password') &&
        (lower.contains('too short') ||
            lower.contains('at least') ||
            lower.contains('weak'))) {
      return 'Choose a stronger password.';
    }
    if (lower.contains('email') &&
        lower.contains('password') &&
        lower.contains('required')) {
      return 'Email and password are required.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email first, then sign in.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (m.isEmpty) return 'That didn’t work. Try again.';
    return 'That didn’t work. Try again.';
  }

  void _showEmailVerificationPrompt({required String email}) {
    setState(() {
      _needsEmailVerification = true;
      _verificationEmail = email;
      _error = null;
    });
  }

  Future<void> _resendVerificationEmail() async {
    final email = (_verificationEmail ?? _email.text).trim();
    if (email.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e).$1);
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  Future<void> _ensureProfile({required String userId}) async {
    try {
      final md =
          Supabase.instance.client.auth.currentUser?.userMetadata ??
          const <String, dynamic>{};
      final given = (md['given_name'] is String)
          ? (md['given_name'] as String).trim()
          : '';
      final family = (md['family_name'] is String)
          ? (md['family_name'] as String).trim()
          : '';
      final metadataDisplayName =
          (md['display_name'] ?? md['full_name'] ?? md['name'])
              ?.toString()
              .trim() ??
          '';
      final metadataRole = md['profile_role']?.toString().trim() ?? '';
      final metadataOrganization = md['organization']?.toString().trim() ?? '';

      final first = _firstName.text.trim();
      final last = _lastName.text.trim();
      final role = _profileRole.text.trim();
      final organization = _organization.text.trim();

      final firstName = first.isNotEmpty ? first : given;
      final lastName = last.isNotEmpty ? last : family;
      final displayName = [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ').trim();

      if (displayName.isEmpty && metadataDisplayName.isEmpty) return;

      if (!_isLogin && _legalAccepted) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: _legalAcceptance),
        );
      }
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'display_name': displayName.isNotEmpty
            ? displayName
            : metadataDisplayName,
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
        if (role.isNotEmpty || metadataRole.isNotEmpty)
          'profile_role': role.isNotEmpty ? role : metadataRole,
        if (organization.isNotEmpty || metadataOrganization.isNotEmpty)
          'organization': organization.isNotEmpty
              ? organization
              : metadataOrganization,
      });
    } catch (e) {
      // acceptable: profile upsert is best-effort at sign-up; auth already
      // succeeded. A missing profile row causes no data loss and will be
      // created lazily on the next authenticated request.
    }
  }

  Future<void> _signInWithApple() async {
    if (_loading) return;
    if (!mounted) return;
    if (!_validateSignupIdentity()) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = OAuthProvider.apple;
      _error = null;
      _needsEmailVerification = false;
      _verificationEmail = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final rawNonce = auth.generateRawNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Apple sign-in did not return an identity token.',
        );
      }

      OnboardingPrefs.justSignedUp = true;
      await _trialIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final userId = auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        OnboardingPrefs.justSignedUp = false;
        throw const AuthException(
          'Something went wrong signing in with Apple.',
        );
      }

      // Apple only returns given/family name on the very first sign-in ever
      // for a given user — capture and persist it now before it's lost.
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      if ((givenName != null && givenName.isNotEmpty) ||
          (familyName != null && familyName.isNotEmpty)) {
        final fullName = [
          givenName,
          familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ');
        try {
          await auth.updateUser(
            UserAttributes(
              data: {
                if (fullName.isNotEmpty) 'full_name': fullName,
                if (givenName != null && givenName.isNotEmpty)
                  'given_name': givenName,
                if (familyName != null && familyName.isNotEmpty)
                  'family_name': familyName,
              },
            ),
          );
        } catch (e) {
          debugPrint('Could not save Apple profile metadata: $e');
          _showMessage('Signed in, but your name could not be saved.');
        }
      }

      await _ensureProfile(userId: userId);
      await OnboardingPrefs.setCoachmarkPending(userId, true);
    } on SignInWithAppleAuthorizationException catch (e) {
      OnboardingPrefs.justSignedUp = false;
      if (e.code != AuthorizationErrorCode.canceled) {
        if (!mounted) return;
        setState(() => _error = 'Apple sign-in failed. Try again.');
        _showMessage(_error!);
      }
    } on AuthException catch (e) {
      OnboardingPrefs.justSignedUp = false;
      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      OnboardingPrefs.justSignedUp = false;
      if (!mounted) return;
      setState(() => _error = describeError(e).$1);
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _oauthProviderLoading = null;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    if (!mounted) return;
    if (!_validateSignupIdentity()) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = OAuthProvider.google;
      _error = null;
      _needsEmailVerification = false;
      _verificationEmail = null;
    });

    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the native sheet — no error to show.
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) {
        throw const AuthException(
          'Google sign-in did not return an identity token.',
        );
      }

      OnboardingPrefs.justSignedUp = true;

      final auth = Supabase.instance.client.auth;

      await _trialIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final userId = auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        OnboardingPrefs.justSignedUp = false;
        throw const AuthException(
          'Something went wrong signing in with Google.',
        );
      }

      await _ensureProfile(userId: userId);
      await OnboardingPrefs.setCoachmarkPending(userId, true);
    } on AuthException catch (e) {
      OnboardingPrefs.justSignedUp = false;
      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      OnboardingPrefs.justSignedUp = false;
      if (!mounted) return;
      setState(() => _error = describeError(e).$1);
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _oauthProviderLoading = null;
        });
      }
    }
  }

  Future<AuthResponse> _trialIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? nonce,
    String? accessToken,
  }) async {
    final auth = Supabase.instance.client.auth;
    await widget.beforeAuth?.call(provider.name, true);
    final response = await auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
      nonce: nonce,
      accessToken: accessToken,
    );
    if (response.user != null) await widget.onSignupUser?.call(response.user!);
    return response;
  }

  static const List<String> _blockedDomains = [
    'mailinator.com',
    'guerrillamail.com',
    'tempmail.com',
    'throwam.com',
    'sharklasers.com',
    'guerrillamailblock.com',
    'grr.la',
    'guerrillamail.info',
    'spam4.me',
    'yopmail.com',
    'yopmail.fr',
    'cool.fr.nf',
    'jetable.fr.nf',
    'nospam.ze.tc',
    'nomail.xl.cx',
    'mega.zik.dj',
    'speed.1s.fr',
    'courriel.fr.nf',
    'moncourrier.fr.nf',
    'monemail.fr.nf',
    'monmail.fr.nf',
    'dispostable.com',
    'mailnull.com',
    'spamgourmet.com',
    'trashmail.com',
    'trashmail.at',
    'trashmail.io',
    'trashmail.me',
    'trashmail.net',
    'discard.email',
    'spambox.us',
    'maildrop.cc',
    'getairmail.com',
    'fakeinbox.com',
    'mailnesia.com',
    'spamfree24.org',
    'tempr.email',
    '0-mail.com',
    '0815.ru',
    '10minutemail.com',
    '10minutemail.net',
    '20minutemail.com',
    'throwaway.email',
    'tempinbox.com',
    'spamherelots.com',
    'spamhereplease.com',
    'spamthisplease.com',
    'tempail.com',
  ];

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  bool _isBlockedDomain(String email) {
    final domain = email.trim().toLowerCase().split('@').last;
    return _blockedDomains.contains(domain);
  }

  Future<void> _submit() async {
    if (!mounted) return;

    if (!_isLogin) {
      if (!_validateSignupIdentity()) return;
      final email = _email.text.trim();
      if (email.isEmpty) {
        setState(() => _emailError = 'Please enter your email.');
        return;
      }
      if (!_isValidEmail(email)) {
        setState(() => _emailError = 'Please enter a valid email address.');
        return;
      }
      if (_isBlockedDomain(email)) {
        setState(() => _emailError = 'Please use a real email address.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _oauthProviderLoading = null;
      _error = null;
      _emailError = null;
      _needsEmailVerification = false;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = _email.text.trim();
      final password = _password.text;

      if (email.isEmpty || password.isEmpty) {
        throw const AuthException('Email and password are required');
      }

      await widget.beforeAuth?.call('email', !_isLogin);
      if (_isLogin) {
        await auth.signInWithPassword(email: email, password: password);
        await auth.refreshSession();

        final userId = Supabase.instance.client.auth.currentUser?.id;
        final confirmedAt =
            Supabase.instance.client.auth.currentSession?.user.emailConfirmedAt;
        if (confirmedAt == null) {
          _showMessage(
            'Please verify your email. Some features may be limited.',
          );
        }

        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        }
      } else {
        OnboardingPrefs.justSignedUp = true;
        final firstName = _firstName.text.trim();
        final lastName = _lastName.text.trim();
        final fullName = [
          firstName,
          lastName,
        ].where((part) => part.isNotEmpty).join(' ');
        final profileRole = _profileRole.text.trim();
        final organization = _organization.text.trim();
        await OnboardingPrefs.setPostSignupPending(true);
        final res = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _oauthRedirectTo,
          data: {
            ..._legalAcceptance,
            'findez_mobile_plan_intro_pending': true,
            if (firstName.isNotEmpty) 'given_name': firstName,
            if (lastName.isNotEmpty) 'family_name': lastName,
            if (fullName.isNotEmpty) 'full_name': fullName,
            if (fullName.isNotEmpty) 'display_name': fullName,
            if (profileRole.isNotEmpty) 'profile_role': profileRole,
            if (organization.isNotEmpty) 'organization': organization,
          },
        );

        if (res.user != null) await widget.onSignupUser?.call(res.user!);

        // Email confirmation required — user created but no active session yet
        if (res.session == null && res.user != null) {
          OnboardingPrefs.justSignedUp = false;
          if (!mounted) return;
          _showEmailVerificationPrompt(email: email);
          return;
        }

        // Sign-up produced no user (service error or unexpected state)
        if (res.user == null) {
          OnboardingPrefs.justSignedUp = false;
          if (!mounted) return;
          setState(() => _error = 'Something went wrong. Try again.');
          _showMessage(_error!);
          return;
        }

        final userId = res.user!.id;
        await _ensureProfile(userId: userId);
        await OnboardingPrefs.setCoachmarkPending(userId, true);
        await OnboardingPrefs.setPostSignupPending(true);
      }
    } on AuthException catch (e) {
      debugPrint('[Auth] AuthException: ${e.message}');
      if (!_isLogin) {
        OnboardingPrefs.justSignedUp = false;
      }

      if (!_isLogin && _isDuplicateEmailMessage(e.message)) {
        const msg =
            'An account with this email already exists. Please sign in.';
        if (!mounted) return;
        setState(() {
          _error = msg;
          _isLogin = true;
          _needsEmailVerification = false;
          _verificationEmail = null;
        });
        _showMessage(msg);
        return;
      }

      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      debugPrint('[Auth] Unknown error: $e');
      if (!_isLogin) {
        OnboardingPrefs.justSignedUp = false;
      }
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Try again.');
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_loading) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Enter your email address first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _emailError = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _oauthRedirectTo,
      );
      _showMessage(
        'If an account exists for $email, a reset link is on its way.',
      );
    } on AuthException catch (error) {
      final friendly = _friendlyAuthError(error.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
      _showMessage(_error!);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _profileRole.dispose();
    _organization.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    int? maxLength,
    List<String>? hints,
    bool password = false,
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    enabled: !_loading,
    keyboardType: keyboard,
    textInputAction: password ? TextInputAction.done : TextInputAction.next,
    autofillHints: hints,
    maxLength: maxLength,
    obscureText: password,
    onChanged: controller == _email
        ? (_) => setState(() => _emailError = null)
        : null,
    onSubmitted: password
        ? (_) => FocusManager.instance.primaryFocus?.unfocus()
        : null,
    style: AppTypography.bodyStyleOf(
      context,
      const TextStyle(
        fontFamily: 'CupertinoSystemText',
        fontSize: 16,
        color: Color(0xFF303030),
      ),
    ),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: icon == null ? null : Icon(icon, size: 21),
      errorText: controller == _email ? _emailError : null,
      filled: true,
      fillColor: Colors.white,
    ),
  );

  Widget _social(
    OAuthProvider provider,
    String label,
    Widget icon,
    VoidCallback action,
  ) => OutlinedButton.icon(
    onPressed: _loading ? null : action,
    icon: _loading && _oauthProviderLoading == provider
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon,
    label: AppText(label, textAlign: TextAlign.center),
    style: OutlinedButton.styleFrom(
      foregroundColor: provider == OAuthProvider.apple
          ? Colors.white
          : const Color(0xFF303030),
      backgroundColor: provider == OAuthProvider.apple
          ? const Color(0xFF303030)
          : Colors.white,
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: BorderSide(color: const Color(0xFF303030), width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'CupertinoSystemText',
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
    ),
  );

  void _switchMode() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLogin = !_isLogin;
      _showEmail = true;
      _needsEmailVerification = false;
      _verificationEmail = null;
      _error = null;
      _emailError = null;
    });
  }

  String get _headline => widget.sampleTrial
      ? 'Now try it on real stuff'
      : widget.trialItemCount != null
      ? 'Keep these ${widget.trialItemCount} items'
      : widget.fromOnboarding
      ? 'Keep your items'
      : _isLogin
      ? 'Welcome back'
      : 'Create your account';
  String get _subtitle => widget.sampleTrial
      ? 'Make a free account, snap a shelf, and FindEZ remembers every item on every device.'
      : widget.fromOnboarding
      ? 'Make an account and FindEZ remembers them, on every device.'
      : _isLogin
      ? 'Sign in to your inventory.'
      : 'Keep your inventory in one place.';

  Widget _heading() => Column(
    children: [
      Semantics(
        header: true,
        child: Text(
          _headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'CupertinoSystemText',
            fontSize: 30,
            fontWeight: FontWeight.w400,
            letterSpacing: -.75,
            height: 1.12,
            color: Color(0xFF303030),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 15,
          height: 1.45,
          color: Color(0xFF6B6965),
        ),
      ),
    ],
  );
  List<Widget> _providers() => [
    _social(
      OAuthProvider.google,
      'Continue with Google',
      const GoogleAuthLogo(size: 22),
      _signInWithGoogle,
    ),
    if (Theme.of(context).platform == TargetPlatform.iOS) ...[
      const SizedBox(height: 14),
      _social(
        OAuthProvider.apple,
        'Continue with Apple',
        const Icon(Icons.apple, size: 25),
        _signInWithApple,
      ),
    ],
  ];
  Widget _legalFooter() => Column(
    children: [
      const Text(
        'By continuing, you acknowledge that you have read and agreed to our',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 12.5,
          height: 1.45,
          color: Color(0xFF6B6965),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TermsOfServicePage(),
              ),
            ),
            child: const Text(
              'Terms of Service',
              style: TextStyle(
                decoration: TextDecoration.underline,
                color: Color(0xFF303030),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyPage(),
              ),
            ),
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                decoration: TextDecoration.underline,
                color: Color(0xFF303030),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  Widget _emailForm({bool providers = true}) => AutofillGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (providers) ...[
          ..._providers(),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE3E3E3))),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'or use email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 13,
                      color: Color(0xFF6B6965),
                    ),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFE3E3E3))),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (!_isLogin) ...[
          _field(
            _firstName,
            'First name',
            maxLength: 50,
            hints: const [AutofillHints.givenName],
          ),
          const SizedBox(height: 12),
          _field(
            _lastName,
            'Last name',
            maxLength: 50,
            hints: const [AutofillHints.familyName],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: const AppText(
              'Work details (optional)',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              _field(
                _profileRole,
                'Role (optional)',
                maxLength: 120,
                hints: const [AutofillHints.jobTitle],
              ),
              const SizedBox(height: 12),
              _field(
                _organization,
                'Organization (optional)',
                maxLength: 120,
                hints: const [AutofillHints.organizationName],
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _field(
          _email,
          'Email',
          icon: Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
          hints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        _field(
          _password,
          'Password',
          icon: Icons.lock_outline_rounded,
          password: true,
          hints: [
            _isLogin ? AutofillHints.password : AutofillHints.newPassword,
          ],
        ),
        if (_isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _sendPasswordReset,
              child: const AppText(
                'Forgot password?',
                style: TextStyle(fontSize: 14),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _legalAccepted,
            onChanged: _loading
                ? null
                : (value) => setState(() => _legalAccepted = value ?? false),
            title: const AppText(
              "I'm at least 13, have any required guardian permission, and accept the Terms of Service.",
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
        if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: AppText(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: _loading && _oauthProviderLoading == null
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AppText(_isLogin ? 'Sign in' : 'Create account'),
        ),

        const SizedBox(height: 16),
        if (_needsEmailVerification) ...[
          Semantics(
            liveRegion: true,
            child: AppText(
              'Check your email to confirm your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: const Color(0xFF6B6965)),
            ),
          ),
          TextButton(
            onPressed: _resending || _loading ? null : _resendVerificationEmail,
            child: AppText(
              _resending ? 'Resending…' : 'Resend verification email',
            ),
          ),
        ],
        TextButton(
          onPressed: _loading ? null : _switchMode,
          child: AppText(
            _isLogin
                ? 'New here? Create account'
                : 'Already have an account? Sign in',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLogin)
          AppText(
            'By signing in, you accept our Terms and confirm you’re eligible (13+).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFF6B6965),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TermsOfServicePage(),
                ),
              ),
              child: const AppText(
                'Terms of Service',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              ),
              child: const AppText(
                'Privacy Policy',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.presentationBuilder != null) {
      return widget.presentationBuilder!(
        context,
        AuthPresentation(
          apple: () {
            if (!_loading) {
              _isLogin = true;
              unawaited(_signInWithApple());
            }
          },
          google: () {
            if (!_loading) {
              _isLogin = true;
              unawaited(_signInWithGoogle());
            }
          },
          email: () => setState(() {
            _showEmail = true;
            _isLogin = false;
            _error = null;
          }),
          closeEmail: () {
            if (!_loading) setState(() => _showEmail = false);
          },
          emailForm: _emailForm(providers: false),
          showEmail: _showEmail,
          busy: _loading,
          method: _loading ? (_oauthProviderLoading?.name ?? 'email') : null,
          error: _error,
        ),
      );
    }
    return _standardPresentation(context);
  }

  Widget _standardPresentation(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F7F6),
      colorScheme: AppTheme.create(Brightness.light).colorScheme,
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'CupertinoSystemText',
        bodyColor: const Color(0xFF303030),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 16,
          color: Color(0xFF6B6965),
        ),
        hintStyle: const TextStyle(color: Color(0xFF8A8782)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF303030),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'CupertinoSystemText',
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF303030),
          minimumSize: const Size(44, 44),
        ),
      ),
    ),
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F6),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              _edge = details.globalPosition.dx <= 24;
              _edgeDistance = 0;
            },
            onHorizontalDragUpdate: (details) {
              if (_edge) _edgeDistance += details.delta.dx;
            },
            onHorizontalDragEnd: (details) {
              if (!_loading &&
                  _edge &&
                  (_edgeDistance > 60 ||
                      (details.primaryVelocity ?? 0) > 300)) {
                widget.onBackToSetup?.call();
              }
              _edge = false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, _showEmail ? 12 : 42, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showEmail)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'All sign-in options',
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _showEmail = false),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                        const Center(child: FindEZWordmark(width: 144)),
                        SizedBox(
                          height: _showEmail
                              ? 28
                              : constraints.maxHeight *
                                    (_moreOptions ? .115 : .20),
                        ),
                        _heading(),
                        SizedBox(
                          height: _showEmail
                              ? 28
                              : constraints.maxHeight * .055,
                        ),
                        if (_showEmail)
                          _emailForm()
                        else ...[
                          ..._providers(),
                          if (_moreOptions) ...[
                            const SizedBox(height: 14),
                            OutlinedButton(
                              key: const Key('auth-email-option'),
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _showEmail = true),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                foregroundColor: const Color(0xFF303030),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF303030),
                                  width: 1.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Continue with Email',
                                style: TextStyle(
                                  fontFamily: 'CupertinoSystemText',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextButton(
                            key: const Key('auth-more-options'),
                            onPressed: _loading
                                ? null
                                : () => setState(
                                    () => _moreOptions = !_moreOptions,
                                  ),
                            child: Text(
                              _moreOptions ? 'Fewer options' : 'More options',
                              style: const TextStyle(
                                fontFamily: 'CupertinoSystemText',
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF303030),
                              ),
                            ),
                          ),
                          if (_error != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 26),
                          _legalFooter(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GoogleAuthLogo extends StatelessWidget {
  const GoogleAuthLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.22;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    void drawArc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint,
      );
    }

    drawArc(-90, 88, const Color(0xFF4285F4));
    drawArc(2, 88, const Color(0xFF34A853));
    drawArc(94, 88, const Color(0xFFFBBC05));
    drawArc(186, 88, const Color(0xFFEA4335));

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.1,
        center.dy - strokeWidth / 2,
        radius - strokeWidth * 0.1,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
