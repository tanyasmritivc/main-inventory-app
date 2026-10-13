import '../../core/app_theme.dart';
import '../../core/ui/findez_wordmark.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_error.dart';
import '../../core/legal_links.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/terms_of_service_page.dart';
import '../onboarding/onboarding_prefs.dart';
import 'package:mobile/core/ui/app_text.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onAuthChanged});

  final VoidCallback? onAuthChanged;

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
  bool _legalAccepted = false;
  Map<String, dynamic> get _legalAcceptance => {
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
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Apple sign-in did not return an identity token.',
        );
      }

      OnboardingPrefs.justSignedUp = true;
      final auth = Supabase.instance.client.auth;
      await auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
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

      await auth.signInWithIdToken(
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
            if (firstName.isNotEmpty) 'given_name': firstName,
            if (lastName.isNotEmpty) 'family_name': lastName,
            if (fullName.isNotEmpty) 'full_name': fullName,
            if (fullName.isNotEmpty) 'display_name': fullName,
            if (profileRole.isNotEmpty) 'profile_role': profileRole,
            if (organization.isNotEmpty) 'organization': organization,
          },
        );

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
      TextStyle(fontSize: 16, color: AppTheme.textPrimary(context)),
    ),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: icon == null ? null : Icon(icon, size: 21),
      errorText: controller == _email ? _emailError : null,
      filled: true,
      fillColor: AppTheme.surface(context),
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
      foregroundColor: AppTheme.textPrimary(context),
      backgroundColor: AppTheme.surface(context),
      minimumSize: const Size(double.infinity, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: BorderSide(
        color: AppTheme.textPrimary(context).withValues(alpha: .18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  void _switchMode() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLogin = !_isLogin;
      _needsEmailVerification = false;
      _verificationEmail = null;
      _error = null;
      _emailError = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FindEZWordmark(width: 144)),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: AppText(
                      _isLogin ? 'Welcome back' : 'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    _isLogin
                        ? 'Sign in to your inventory.'
                        : 'Keep your inventory in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 28),
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
                      _isLogin
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
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
                          : (value) =>
                                setState(() => _legalAccepted = value ?? false),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    child: _loading && _oauthProviderLoading == null
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppText(_isLogin ? 'Sign in' : 'Create account'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: AppText(
                          'or',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                    _social(
                      OAuthProvider.apple,
                      'Continue with Apple',
                      const Icon(Icons.apple, size: 22),
                      _signInWithApple,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _social(
                    OAuthProvider.google,
                    'Continue with Google',
                    const _GoogleLogo(size: 20),
                    _signInWithGoogle,
                  ),
                  const SizedBox(height: 16),
                  if (_needsEmailVerification) ...[
                    Semantics(
                      liveRegion: true,
                      child: AppText(
                        'Check your email to confirm your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _resending || _loading
                          ? null
                          : _resendVerificationEmail,
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
                        color: AppTheme.textSecondary(context),
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
            ),
          ),
        ),
      ),
    ),
  );
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 20});

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
