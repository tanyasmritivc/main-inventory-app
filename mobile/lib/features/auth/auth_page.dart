import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_error.dart';
import '../onboarding/onboarding_prefs.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onAuthChanged});

  final VoidCallback? onAuthChanged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _isLogin = true;
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
    _email = TextEditingController();
    _password = TextEditingController();
    assert(() {
      final keepAlive = <Object?>[
        _oauthSignIn,
      ];
      return keepAlive.isNotEmpty;
    }());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        )
      );
  }

  Future<void> _oauthSignIn(OAuthProvider provider) async {
    if (_loading) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = provider;
      _error = null;
      _needsEmailVerification = false;
      _verificationEmail = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectTo,
      );
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

      final first = _firstName.text.trim();
      final last = _lastName.text.trim();

      final firstName = first.isNotEmpty ? first : given;
      final lastName = last.isNotEmpty ? last : family;

      if (firstName.isEmpty && lastName.isEmpty) return;

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
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
    'mailinator.com', 'guerrillamail.com', 'tempmail.com', 'throwam.com',
    'sharklasers.com', 'guerrillamailblock.com', 'grr.la', 'guerrillamail.info',
    'spam4.me', 'yopmail.com', 'yopmail.fr', 'cool.fr.nf', 'jetable.fr.nf',
    'nospam.ze.tc', 'nomail.xl.cx', 'mega.zik.dj', 'speed.1s.fr',
    'courriel.fr.nf', 'moncourrier.fr.nf', 'monemail.fr.nf', 'monmail.fr.nf',
    'dispostable.com', 'mailnull.com', 'spamgourmet.com', 'trashmail.com',
    'trashmail.at', 'trashmail.io', 'trashmail.me', 'trashmail.net',
    'discard.email', 'spambox.us', 'maildrop.cc', 'getairmail.com',
    'fakeinbox.com', 'mailnesia.com', 'spamfree24.org',
    'tempr.email', '0-mail.com', '0815.ru',
    '10minutemail.com', '10minutemail.net', '20minutemail.com',
    'throwaway.email', 'tempinbox.com', 'spamherelots.com',
    'spamhereplease.com', 'spamthisplease.com', 'tempail.com',
  ];

  bool _isValidEmail(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email.trim());
  }

  bool _isBlockedDomain(String email) {
    final domain = email.trim().toLowerCase().split('@').last;
    return _blockedDomains.contains(domain);
  }

  Future<void> _submit() async {
    if (!mounted) return;

    if (!_isLogin) {
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
        final confirmedAt = Supabase
            .instance
            .client
            .auth
            .currentSession
            ?.user
            .emailConfirmedAt;
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
        final res = await auth.signUp(email: email, password: password);

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

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign in' : 'Create account'),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.9,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 28,
                            sigmaY: 28,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF5E5CE6)
                                      .withValues(alpha: 0.20),
                                  const Color(0xFFC084FC)
                                      .withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  Text(
                    _isLogin ? 'Welcome back' : 'Welcome',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'by AI Robots Inc',
                    style: TextStyle(
                      color: Color(0x4DFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Sign in to upload documents and view activity.'
                        : 'Sign up to start uploading documents.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_isLogin) ...[
                    TextField(
                      controller: _firstName,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: Color(0xFF171717),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                        ),
                      ),
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: Color(0xFF171717),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                        ),
                      ),
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (_) => setState(() => _emailError = null),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@company.com',
                      hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                      filled: true,
                      fillColor: Color(0xFF171717),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                      ),
                    ),
                    autofillHints: const [AutofillHints.email],
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _emailError!,
                        style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      filled: true,
                      fillColor: Color(0xFF171717),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                      ),
                    ),
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x14FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.4),
                      minimumSize: const Size(double.infinity, 50),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                    child: (_loading && _oauthProviderLoading == null)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('Please wait…'),
                            ],
                          )
                        : Text(_isLogin ? 'Sign in' : 'Create account'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                    _SocialButton(
                      enabled: !_loading,
                      onPressed: _loading ? null : _signInWithApple,
                      icon: const Icon(Icons.apple, color: Colors.white, size: 18),
                      label: const Text(
                        'Continue with Apple',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SocialButton(
                    enabled: !_loading,
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: (_loading && _oauthProviderLoading == OAuthProvider.google)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const _GoogleLogo(size: 18),
                    label: Text(
                      (_loading && _oauthProviderLoading == OAuthProvider.google)
                          ? 'Please wait…'
                          : 'Continue with Google',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_needsEmailVerification) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x14FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mark_email_unread_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Check your email to confirm your account before logging in.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: (_resending || _loading)
                                ? null
                                : _resendVerificationEmail,
                            child: Text(
                              _resending
                                  ? 'Resending…'
                                  : 'Resend verification email',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _needsEmailVerification = false;
                              _verificationEmail = null;
                              _error = null;
                              _emailError = null;
                            });
                          },
                    child: Text(
                      _isLogin
                          ? 'Need an account? Sign up'
                          : 'Have an account? Login',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.enabled,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  double _pressedOpacity = 1;

  void _setPressed(bool pressed) {
    if (!mounted) return;
    setState(() => _pressedOpacity = pressed ? 0.7 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? _pressedOpacity : 0.5,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.icon,
                const SizedBox(width: 10),
                widget.label,
              ],
            ),
          ),
        ),
      ),
    );
  }
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
