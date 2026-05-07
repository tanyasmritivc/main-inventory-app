import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
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
      setState(() => _error = 'Something went wrong. Try again.');
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
      setState(() => _error = 'Something went wrong. Try again.');
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
      // ignore
    }
  }

  Future<void> _submit() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = null;
      _error = null;
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
        final res = await auth.signUp(email: email, password: password);
        if (res.user != null) {
          try {
            await auth.refreshSession();
          } catch (_) {
          }

          if (auth.currentSession == null) {
            try {
              await auth.signInWithPassword(
                email: email,
                password: password,
              );
              await auth.refreshSession();
            } on AuthException catch (_) {
            } catch (_) {
            }
          }
        }

        widget.onAuthChanged?.call();

        if (res.user == null && res.session == null) {
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

        final userId = res.user?.id;
        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        } else {
          debugPrint(
            '[Auth] signUp did not return a user (email=$email). session=${res.session != null}',
          );
          if (!mounted) return;
          setState(() {
            _error = 'That didn’t work. Try again.';
          });
          _showMessage(_error!);
          return;
        }

        await OnboardingPrefs.setPostSignupPending(true);

        final confirmedAt = res.session?.user.emailConfirmedAt;
        if (confirmedAt == null) {
          _showMessage(
            'Please verify your email. Some features may be limited.',
          );

          if (res.session == null) {
            _showEmailVerificationPrompt(email: email);
          }
          return;
        }
      }
    } on AuthException catch (e) {
      debugPrint('[Auth] AuthException: ${e.message}');

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
                                  const Color(0xFF60A5FA)
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
                  GlassCard(
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
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastName,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@company.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: 16,
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
                  PrimaryGradientButton(
                    onPressed: _loading ? null : _submit,
                    borderRadius: 999,
                    height: 50,
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
                                    Colors.white.withValues(alpha: 0.9),
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
                  if (_needsEmailVerification) ...[
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: 16,
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
                                  'Please verify your email before signing in. Check your inbox.',
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
